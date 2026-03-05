"""Dynamics 365 Business Central connector for Lakeflow."""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from typing import Iterator

from pyspark.sql.types import (
    BooleanType,
    DecimalType,
    LongType,
    StringType,
    StructField,
    StructType,
)

from databricks.labs.community_connector.interface import LakeflowConnect
from databricks.labs.community_connector.sources.dynamics_business_central.dynamics_business_central_schemas import (
    BASE_URL_TEMPLATE,
    EDM_TYPE_MAP,
    INITIAL_BACKOFF,
    LOOKBACK_SECONDS,
    MAX_RETRIES,
    RETRIABLE_STATUS_CODES,
    TABLE_REGISTRY,
    TOKEN_SCOPE,
    TOKEN_URL_TEMPLATE,
)


class DynamicsBusinessCentralLakeflowConnect(LakeflowConnect):

    def __init__(self, options: dict[str, str]) -> None:
        super().__init__(options)
        self._tenant_id = options["tenant_id"]
        self._client_id = options["client_id"]
        self._client_secret = options["client_secret"]
        self._environment = options["environment"]
        self._company_id = options["company_id"]

        self._base_url = BASE_URL_TEMPLATE.format(
            tenant_id=self._tenant_id, environment=self._environment
        )
        self._access_token: str | None = None
        self._token_expires_at: float = 0.0

        self._init_ts = datetime.now(timezone.utc).isoformat()
        self._lookback_applied = False

        self._schema_cache: dict[str, StructType] = {}

    # ── Authentication ────────────────────────────────────────────────────

    def _ensure_token(self) -> str:
        if self._access_token and time.time() < self._token_expires_at - 60:
            return self._access_token

        token_url = TOKEN_URL_TEMPLATE.format(tenant_id=self._tenant_id)
        body = urllib.parse.urlencode({
            "grant_type": "client_credentials",
            "client_id": self._client_id,
            "client_secret": self._client_secret,
            "scope": TOKEN_SCOPE,
        }).encode()

        req = urllib.request.Request(token_url, data=body, method="POST")
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())

        self._access_token = data["access_token"]
        self._token_expires_at = time.time() + int(data.get("expires_in", 3600))
        return self._access_token

    # ── HTTP helpers ──────────────────────────────────────────────────────

    def _api_get(self, url: str) -> dict:
        """GET with retries and exponential backoff on transient errors."""
        token = self._ensure_token()
        backoff = INITIAL_BACKOFF
        last_error = None

        for attempt in range(MAX_RETRIES):
            req = urllib.request.Request(url, headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
            })
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    return json.loads(resp.read())
            except urllib.error.HTTPError as e:
                last_error = e
                if e.code == 401:
                    self._access_token = None
                    token = self._ensure_token()
                    continue
                if e.code in RETRIABLE_STATUS_CODES:
                    retry_after = e.headers.get("Retry-After")
                    wait = float(retry_after) if retry_after else backoff
                    if attempt < MAX_RETRIES - 1:
                        time.sleep(wait)
                        backoff *= 2
                    continue
                raise RuntimeError(
                    f"API request failed: HTTP {e.code} for {url}: "
                    f"{e.read().decode()[:500]}"
                ) from e
            except urllib.error.URLError as e:
                last_error = e
                if attempt < MAX_RETRIES - 1:
                    time.sleep(backoff)
                    backoff *= 2
                    continue
                raise

        raise RuntimeError(
            f"API request failed after {MAX_RETRIES} retries: {last_error}"
        )

    def _api_post(self, url: str, payload: dict) -> dict:
        token = self._ensure_token()
        data = json.dumps(payload).encode()
        req = urllib.request.Request(url, data=data, method="POST", headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            raise RuntimeError(
                f"POST failed: HTTP {e.code} for {url}: "
                f"{e.read().decode()[:500]}"
            ) from e

    def _build_url(self, table_name: str) -> str:
        meta = TABLE_REGISTRY[table_name]
        group = meta["api_group"]
        if meta["company_scoped"]:
            return (
                f"{self._base_url}/api/databricks/{group}/v1.0"
                f"/companies({self._company_id})/{table_name}"
            )
        return f"{self._base_url}/api/databricks/{group}/v1.0/{table_name}"

    def _build_delete_tracking_url(self, entity: str) -> str:
        return (
            f"{self._base_url}/api/databricks/deleteTracking/v1.0"
            f"/companies({self._company_id})/{entity}"
        )

    # ── Schema discovery via $metadata ────────────────────────────────────

    def _fetch_edmx_schema(self, api_group: str) -> dict[str, StructType]:
        """Fetch $metadata EDMX and parse entity types into Spark StructTypes.

        Returns a dict keyed by EntitySet name (= entitySetName from AL) so
        callers can look up by table_name directly.
        """
        url = (
            f"{self._base_url}/api/databricks/{api_group}/v1.0/$metadata"
        )
        token = self._ensure_token()
        req = urllib.request.Request(url, headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/xml",
        })
        with urllib.request.urlopen(req, timeout=30) as resp:
            xml_text = resp.read().decode()

        root = ET.fromstring(xml_text)
        ns = {
            "edmx": "http://docs.oasis-open.org/odata/ns/edmx",
            "edm": "http://docs.oasis-open.org/odata/ns/edm",
        }

        type_schemas: dict[str, StructType] = {}
        for entity_type in root.findall(".//edm:EntityType", ns):
            type_name = entity_type.get("Name", "")
            fields: list[StructField] = []
            for prop in entity_type.findall("edm:Property", ns):
                prop_name = prop.get("Name", "")
                edm_type = prop.get("Type", "Edm.String")
                spark_type_cls = EDM_TYPE_MAP.get(edm_type, StringType)
                if spark_type_cls is DecimalType:
                    spark_type = DecimalType(38, 10)
                else:
                    spark_type = spark_type_cls()
                fields.append(StructField(prop_name, spark_type, nullable=True))
            if fields:
                type_schemas[type_name] = StructType(fields)

        # Build EntitySet name -> EntityType name mapping from the EDMX
        set_to_type: dict[str, str] = {}
        for entity_set in root.findall(".//edm:EntitySet", ns):
            set_name = entity_set.get("Name", "")
            entity_type_ref = entity_set.get("EntityType", "")
            # EntityType is fully qualified, e.g. "Microsoft.NAV.customer"
            short_type = entity_type_ref.rsplit(".", 1)[-1] if "." in entity_type_ref else entity_type_ref
            set_to_type[set_name] = short_type

        # Return keyed by EntitySet name for direct lookup
        schemas: dict[str, StructType] = {}
        for set_name, type_name in set_to_type.items():
            if type_name in type_schemas:
                schemas[set_name] = type_schemas[type_name]

        return schemas

    def _resolve_schema(self, table_name: str) -> StructType:
        if table_name in self._schema_cache:
            return self._schema_cache[table_name]

        meta = TABLE_REGISTRY[table_name]
        group = meta["api_group"]

        group_schemas = self._fetch_edmx_schema(group)

        matched = group_schemas.get(table_name)
        if matched is None:
            matched = self._infer_schema_from_sample(table_name)

        self._schema_cache[table_name] = matched
        return matched

    def _infer_schema_from_sample(self, table_name: str) -> StructType:
        url = self._build_url(table_name) + "?$top=1"
        data = self._api_get(url)
        records = data.get("value", [])
        if not records:
            raise RuntimeError(
                f"Cannot infer schema for '{table_name}': no records returned "
                f"and $metadata matching failed."
            )
        sample = records[0]
        fields = []
        for key, value in sample.items():
            if key.startswith("@odata"):
                continue
            spark_type = self._guess_spark_type(value)
            fields.append(StructField(key, spark_type, nullable=True))
        return StructType(fields)

    @staticmethod
    def _guess_spark_type(value):
        if isinstance(value, bool):
            return BooleanType()
        if isinstance(value, int):
            return LongType()
        if isinstance(value, float):
            return DecimalType(38, 10)
        return StringType()

    # ── Interface: list_tables ────────────────────────────────────────────

    def list_tables(self) -> list[str]:
        return list(TABLE_REGISTRY.keys())

    # ── Interface: get_table_schema ───────────────────────────────────────

    def get_table_schema(
        self, table_name: str, table_options: dict[str, str]
    ) -> StructType:
        self._validate_table(table_name)
        return self._resolve_schema(table_name)

    # ── Interface: read_table_metadata ────────────────────────────────────

    def read_table_metadata(
        self, table_name: str, table_options: dict[str, str]
    ) -> dict:
        self._validate_table(table_name)
        meta = TABLE_REGISTRY[table_name]
        result: dict = {
            "ingestion_type": meta["ingestion_type"],
            "primary_keys": meta["primary_keys"],
        }
        if meta["cursor_field"]:
            result["cursor_field"] = meta["cursor_field"]
        return result

    # ── Interface: read_table ─────────────────────────────────────────────

    def read_table(
        self, table_name: str, start_offset: dict, table_options: dict[str, str]
    ) -> tuple[Iterator[dict], dict]:
        self._validate_table(table_name)
        meta = TABLE_REGISTRY[table_name]
        ingestion_type = meta["ingestion_type"]

        if ingestion_type == "snapshot":
            return self._read_snapshot(table_name)

        cursor_field = meta["cursor_field"]
        if ingestion_type == "append":
            return self._read_append(
                table_name, start_offset, table_options, cursor_field
            )
        # cdc and cdc_with_deletes
        return self._read_cdc(
            table_name, start_offset, table_options, cursor_field
        )

    # ── Interface: read_table_deletes ─────────────────────────────────────

    def read_table_deletes(
        self, table_name: str, start_offset: dict, table_options: dict[str, str]
    ) -> tuple[Iterator[dict], dict]:
        self._validate_table(table_name)
        meta = TABLE_REGISTRY[table_name]
        if meta["ingestion_type"] != "cdc_with_deletes":
            raise ValueError(
                f"Table '{table_name}' does not support delete tracking "
                f"(ingestion_type={meta['ingestion_type']})"
            )
        bc_table_id = meta["bc_table_id"]
        if bc_table_id is None:
            raise ValueError(
                f"Table '{table_name}' has no BC table ID for delete tracking"
            )

        since = start_offset.get("delete_cursor") if start_offset else None
        if since and since >= self._init_ts:
            return iter([]), start_offset

        max_records = int(table_options.get("max_records_per_batch", "200"))
        base = self._build_delete_tracking_url("deletedRecords")

        filter_parts = [
            f"tableId eq {bc_table_id}",
            f"companyId eq '{self._company_id}'",
        ]
        if since:
            filter_parts.append(f"deletedAt gt {since}")

        filter_str = " and ".join(filter_parts)
        url = f"{base}?$filter={urllib.parse.quote(filter_str)}&$orderby={urllib.parse.quote('deletedAt asc')}"

        records: list[dict] = []
        while len(records) < max_records:
            data = self._api_get(url)
            batch = data.get("value", [])
            if not batch:
                break

            for rec in batch:
                records.append({
                    "systemId": rec["deletedSystemId"],
                    "systemModifiedAt": rec["deletedAt"],
                })
                if len(records) >= max_records:
                    break

            next_link = data.get("@odata.nextLink")
            if not next_link or len(records) >= max_records:
                break
            url = next_link

        if not records:
            return iter([]), start_offset or {}

        last_cursor = records[-1]["systemModifiedAt"]
        end_offset = {"delete_cursor": last_cursor}
        if start_offset and start_offset == end_offset:
            return iter([]), start_offset

        return iter(records), end_offset

    # ── Private: read strategies ──────────────────────────────────────────

    def _read_snapshot(
        self, table_name: str
    ) -> tuple[Iterator[dict], dict]:
        url = self._build_url(table_name)
        records: list[dict] = []
        while url:
            data = self._api_get(url)
            for rec in data.get("value", []):
                records.append(self._strip_odata_fields(rec))
            url = data.get("@odata.nextLink")
        return iter(records), {}

    def _read_cdc(
        self,
        table_name: str,
        start_offset: dict,
        table_options: dict[str, str],
        cursor_field: str,
    ) -> tuple[Iterator[dict], dict]:
        """CDC read for cdc and cdc_with_deletes tables. Client-side truncation safe."""
        since = start_offset.get("cursor") if start_offset else None
        if since and since >= self._init_ts:
            return iter([]), start_offset

        max_records = int(table_options.get("max_records_per_batch", "200"))
        window_seconds = int(table_options.get("window_seconds", "3600"))

        effective_since = since
        if effective_since and not self._lookback_applied:
            dt = datetime.fromisoformat(effective_since)
            dt = dt - timedelta(seconds=LOOKBACK_SECONDS)
            effective_since = dt.isoformat()
            self._lookback_applied = True

        if effective_since:
            window_end_dt = datetime.fromisoformat(effective_since) + timedelta(
                seconds=window_seconds
            )
            window_end = min(window_end_dt.isoformat(), self._init_ts)
        else:
            window_end = self._init_ts

        url = self._build_filtered_url(
            table_name, cursor_field, effective_since, window_end
        )

        records: list[dict] = []
        while len(records) < max_records:
            data = self._api_get(url)
            batch = data.get("value", [])
            if not batch:
                break

            for rec in batch:
                records.append(self._strip_odata_fields(rec))
                if len(records) >= max_records:
                    break

            next_link = data.get("@odata.nextLink")
            if not next_link or len(records) >= max_records:
                break
            url = next_link

        if not records:
            end_offset = {"cursor": window_end}
            if start_offset and start_offset == end_offset:
                return iter([]), start_offset
            return iter([]), end_offset

        last_cursor = records[-1][cursor_field]
        end_offset = {"cursor": last_cursor}
        if start_offset and start_offset == end_offset:
            return iter([]), start_offset

        return iter(records), end_offset

    def _read_append(
        self,
        table_name: str,
        start_offset: dict,
        table_options: dict[str, str],
        cursor_field: str,
    ) -> tuple[Iterator[dict], dict]:
        """Append read. No client-side truncation — must process full pages."""
        since = start_offset.get("cursor") if start_offset else None
        if since and since >= self._init_ts:
            return iter([]), start_offset

        max_records = int(table_options.get("max_records_per_batch", "200"))
        window_seconds = int(table_options.get("window_seconds", "3600"))

        effective_since = since
        if effective_since and not self._lookback_applied:
            dt = datetime.fromisoformat(effective_since)
            dt = dt - timedelta(seconds=LOOKBACK_SECONDS)
            effective_since = dt.isoformat()
            self._lookback_applied = True

        if effective_since:
            window_end_dt = datetime.fromisoformat(effective_since) + timedelta(
                seconds=window_seconds
            )
            window_end = min(window_end_dt.isoformat(), self._init_ts)
        else:
            window_end = self._init_ts

        url = self._build_filtered_url(
            table_name, cursor_field, effective_since, window_end
        )

        records: list[dict] = []
        while True:
            data = self._api_get(url)
            batch = data.get("value", [])
            if not batch:
                break

            for rec in batch:
                records.append(self._strip_odata_fields(rec))

            next_link = data.get("@odata.nextLink")
            if not next_link:
                break
            if len(records) >= max_records:
                break
            url = next_link

        if not records:
            end_offset = {"cursor": window_end}
            if start_offset and start_offset == end_offset:
                return iter([]), start_offset
            return iter([]), end_offset

        last_cursor = records[-1][cursor_field]
        end_offset = {"cursor": last_cursor}
        if start_offset and start_offset == end_offset:
            return iter([]), start_offset

        return iter(records), end_offset

    # ── URL building ──────────────────────────────────────────────────────

    def _build_filtered_url(
        self,
        table_name: str,
        cursor_field: str,
        since: str | None,
        until: str | None,
    ) -> str:
        base = self._build_url(table_name)
        filter_parts = []
        if since:
            filter_parts.append(f"{cursor_field} gt {since}")
        if until:
            filter_parts.append(f"{cursor_field} le {until}")

        params = {}
        if filter_parts:
            params["$filter"] = " and ".join(filter_parts)
        params["$orderby"] = f"{cursor_field} asc"

        return base + "?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)

    # ── Delete tracker registration ───────────────────────────────────────

    def ensure_delete_trackers(self) -> None:
        """Register delete trackers for all cdc_with_deletes tables.

        Call this once after deployment to ensure the event handler captures
        deletes for the tables this connector cares about.
        """
        tracker_url = self._build_delete_tracking_url("deleteTrackers")

        existing = set()
        url = tracker_url
        while url:
            data = self._api_get(url)
            for rec in data.get("value", []):
                existing.add((rec["tableId"], rec["companyId"]))
            url = data.get("@odata.nextLink")

        for table_name, meta in TABLE_REGISTRY.items():
            if meta["ingestion_type"] != "cdc_with_deletes":
                continue
            bc_id = meta.get("bc_table_id")
            if bc_id is None:
                continue
            key = (bc_id, self._company_id)
            if key not in existing:
                self._api_post(tracker_url, {
                    "tableId": bc_id,
                    "companyId": self._company_id,
                })

    # ── Helpers ───────────────────────────────────────────────────────────

    def _validate_table(self, table_name: str) -> None:
        if table_name not in TABLE_REGISTRY:
            raise ValueError(
                f"Table '{table_name}' is not supported. "
                f"Supported tables: {list(TABLE_REGISTRY.keys())}"
            )

    @staticmethod
    def _strip_odata_fields(record: dict) -> dict:
        return {k: v for k, v in record.items() if not k.startswith("@odata")}
