"""
Test API access across all endpoint groups after extension redeployment.
Checks: token acquisition, metadata, standardEndpoints, and deleteTracking.
"""
import sys
import json
import urllib.request
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from tests.unit.sources.test_utils import load_config


def get_token(tenant_id, client_id, client_secret):
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    token_data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": "https://api.businesscentral.dynamics.com/.default",
    }).encode()
    req = urllib.request.Request(token_url, data=token_data, method="POST")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())["access_token"]


def call_api(base, path, token, top=1):
    url = f"{base}{path}{'&' if '?' in path else '?'}$top={top}"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read())
            records = data.get("value", [])
            return True, len(records), records
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        return False, e.code, body


def main():
    config = load_config(Path(__file__).parent / "configs" / "dev_config.json")
    tid = config["tenant_id"]
    env = config["environment"]
    cid = config["company_id"]

    print("=== Dynamics 365 Business Central API Access Test ===\n")

    print("1. Acquiring token...")
    try:
        token = get_token(tid, config["client_id"], config["client_secret"])
        print("   OK\n")
    except Exception as e:
        print(f"   FAILED: {e}\n")
        return False

    base = f"https://api.businesscentral.dynamics.com/v2.0/{tid}/{env}"

    endpoints = [
        ("metadata",          f"/api/databricks/metadata/v1.0/companies({cid})/pageMetadata"),
        ("metadata",          f"/api/databricks/metadata/v1.0/companies({cid})/tableMetadata"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/countriesRegions"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/customers"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/glAccounts"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/items"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/vendors"),
        ("standardEndpoints", f"/api/databricks/standardEndpoints/v1.0/companies({cid})/salesInvoiceHeaders"),
        ("deleteTracking",    f"/api/databricks/deleteTracking/v1.0/companies({cid})/deletedRecords"),
        ("deleteTracking",    f"/api/databricks/deleteTracking/v1.0/companies({cid})/deleteTrackers"),
    ]

    print("2. Testing endpoints:\n")
    all_ok = True
    for group, path in endpoints:
        entity = path.rsplit("/", 1)[-1].split("?")[0]
        ok, count_or_code, data = call_api(base, path, token)
        if ok:
            print(f"   OK   [{group}] {entity}  ({count_or_code} record(s))")
        else:
            print(f"   FAIL [{group}] {entity}  HTTP {count_or_code}: {data}")
            all_ok = False

    print(f"\n{'All endpoints accessible!' if all_ok else 'Some endpoints FAILED — check permissions and extension deployment.'}")
    return all_ok


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
