# Lakeflow Microsoft Dynamics 365 Business Central Community Connector

This documentation provides setup instructions and reference information for the Microsoft Dynamics 365 Business Central source connector.

## Prerequisites

- A **Dynamics 365 Business Central** environment (Production or Sandbox) with admin access.
- An **Azure tenant** where you can register applications.
- A **Databricks workspace** with Unity Catalog and Lakeflow Connect enabled.

## Setup

Follow these steps in order. Each step depends on the previous one.

### Step 1: Deploy the AL Extension

The connector reads data from Business Central through custom OData API pages exposed by an AL extension. This extension must be deployed before the connector can access any data.

The AL extension (`initialSetup_databricks.al`) provides:
- **51 custom API pages** that expose Business Central tables via OData (customers, vendors, items, GL entries, etc.).
- **Delete tracking infrastructure** — a log table, an event handler codeunit, and a tracker registration table that capture record deletions for incremental sync.
- **A permission set** (`CONNECTOR_SETUP`) that grants the necessary table-level permissions.

**To deploy:**

1. Open the AL project in **Visual Studio Code** with the [AL Language extension](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al) installed.
2. Set your Business Central environment as the target in `launch.json`.
3. Run **AL: Publish** (Ctrl+F5) to publish and install the extension.

Alternatively, package the extension as an `.app` file and upload it via the **Extension Management** page in Business Central (search for "Extension Management" in the BC search bar).

> **Verify deployment:** After publishing, open the BC web client and search for **"Web Services"**. You should see API pages with the publisher `databricks` listed (e.g., `customers`, `vendors`, `items`).

### Step 2: Register an Azure AD App

The connector authenticates to Business Central using OAuth 2.0 Client Credentials. You need an Azure AD (Microsoft Entra ID) app registration.

1. Go to the [Azure Portal](https://portal.azure.com/) > **Microsoft Entra ID** > **App registrations** > **New registration**.
2. Name the app (e.g., "Databricks BC Connector"), leave the default settings, and click **Register**.
3. On the **Overview** page, copy:
   - **Application (client) ID** → this is your `client_id`
   - **Directory (tenant) ID** → this is your `tenant_id`
4. Go to **API permissions** > **Add a permission** > **APIs my organization uses** > search for **Dynamics 365 Business Central** > select **Application permissions** > add **`API.ReadWrite.All`** > click **Grant admin consent**.
5. Go to **Certificates & secrets** > **Client secrets** > **New client secret** > set an expiry > click **Add**. Copy the secret **Value** immediately (it won't be shown again) → this is your `client_secret`.

### Step 3: Authorize the App in Business Central

The Azure AD app must be registered inside Business Central and assigned the correct permission sets. This is a critical step — without it, the app can authenticate but cannot read or write data.

1. In Business Central, search for **"Microsoft Entra Applications"** (or **"Azure Active Directory Applications"** in older versions).
2. Click **+ New** to add a new entry.
3. In the **Client ID** field, paste your app's `client_id` from Step 2.
4. Set **State** to **Enabled**.
5. Give it a description (e.g., "Databricks Connector").
6. In the **User Permission Sets** section at the bottom, add the following permission sets:

| Permission Set | Purpose |
|---|---|
| `D365 BUS FULL ACCESS` | Grants read access to all standard Business Central tables. Required for the connector to read company data. |
| `CONNECTOR_SETUP` | Grants read/write access to the delete tracking tables (`Deleted Record` and `Delete Tracker`). Required for registering delete trackers and reading deletion events. Included in the AL extension. |

> **Why both?** `D365 BUS FULL ACCESS` provides broad read access to BC data tables. `CONNECTOR_SETUP` provides write access specifically to the custom delete tracking tables (90100, 90101) deployed by the AL extension. Without `CONNECTOR_SETUP`, the connector can read data but cannot register delete trackers or read delete events.

### Step 4: Find Your Company ID

The connector requires the Business Central company ID (a GUID) to scope API calls to a specific company.

**Option A — From the BC web client URL:**
Navigate to any page in Business Central. The URL contains the company ID:
```
https://businesscentral.dynamics.com/{tenant_id}/{environment}/?company={company_id}
```

**Option B — Via the API:**
After the app is authorized, query the companies endpoint:
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies
```

**Option C — From within Databricks:**
After the pipeline is running, query the `rawCompanies` table which lists all companies and their IDs.

### Step 5: Register Delete Trackers

Delete tracking requires explicit registration for each table you want to track. The AL extension's event handler only captures deletes for tables that have an active tracker entry.

**This is a one-time setup step.** You must register trackers before any deletes can be captured. Deletes that occur before registration are not captured retroactively.

The connector can register trackers programmatically via the `deleteTrackers` API endpoint:

```
POST https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/deleteTracking/v1.0/companies({company_id})/deleteTrackers
Content-Type: application/json

{
  "tableId": 18,
  "companyId": "{company_id}"
}
```

Each tracked table has a unique BC table ID. The full mapping is:

| Table | BC Table ID | | Table | BC Table ID |
|---|---|---|---|---|
| `generalLedgerAccounts` | 15 | | `paymentMethods` | 289 |
| `bankAccounts` | 270 | | `paymentTerms` | 3 |
| `contacts` | 5050 | | `purchaseLines` | 39 |
| `countriesRegions` | 9 | | `jobs` | 167 |
| `currencies` | 4 | | `shipmentMethods` | 10 |
| `currencyExchangeRates` | 330 | | `unitsOfMeasure` | 204 |
| `customers` | 18 | | `timeSheetDetails` | 953 |
| `generalJournalBatches` | 232 | | `salesHeaders` | 36 |
| `reasonCodes` | 231 | | `salesLines` | 37 |
| `generalJournalLines` | 81 | | `purchaseHeaders` | 38 |
| `defaultDimensions` | 352 | | `vendors` | 23 |
| `dimensionValues` | 349 | | `inventoryPostingGroups` | 94 |
| `dimensions` | 348 | | `itemCategories` | 5722 |
| `employees` | 5200 | | `itemVariants` | 5401 |
| `generalProductPostingGroups` | 251 | | `items` | 27 |
| `locations` | 14 | | `opportunities` | 5092 |

You can verify existing registrations by querying:
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/deleteTracking/v1.0/companies({company_id})/deleteTrackers
```

> **Important:** If you skip this step, inserts and updates will work correctly, but deletes will not be captured. You can register trackers at any time, but only deletes occurring after registration will be tracked.

### Step 6: Create a Unity Catalog Connection

Create a connection in Databricks to store the Business Central credentials securely.

**Via the CLI:**
```bash
community-connector create_connection dynamics_business_central <CONNECTION_NAME> -o '{
  "tenant_id": "<YOUR_TENANT_ID>",
  "client_id": "<YOUR_CLIENT_ID>",
  "client_secret": "<YOUR_CLIENT_SECRET>",
  "environment": "<Production_or_Sandbox>",
  "company_id": "<YOUR_COMPANY_ID>"
}'
```

**Via the UI:**
1. In Databricks, go to **Catalog** > **External Data** > **Connections** > **Create connection**.
2. Select **Lakeflow Community Connector** as the connection type.
3. Enter the five required parameters (see table below).
4. Set the `externalOptionsAllowList` to `max_records_per_batch,window_seconds`.

### Required Connection Parameters

| Parameter | Type | Description |
|---|---|---|
| `tenant_id` | string | Azure AD tenant ID (GUID). Found on the app registration Overview page. |
| `client_id` | string | Application (client) ID (GUID). Found on the app registration Overview page. |
| `client_secret` | string (secret) | Client secret value from the app registration's Certificates & secrets page. |
| `environment` | string | Business Central environment name, e.g. `Production` or `Sandbox`. |
| `company_id` | string | Business Central company ID (GUID). See [Step 4](#step-4-find-your-company-id). |


## Supported Objects

This connector supports **51 objects** organized into four categories. Object names are case-sensitive and must be specified exactly as shown.

### Metadata Objects (Snapshot)

These objects are refreshed fully on each run.

| Object Name | Description | Primary Key |
|---|---|---|
| `pageMetadata` | Metadata about API pages deployed in the system | `id` |
| `tableMetadata` | Metadata about tables in the system | `id` |

### Master Data & Setup Objects (CDC with Deletes)

These objects support incremental ingestion via `systemModifiedAt` and delete synchronization. Records that are modified or created since the last sync are captured; records deleted from the source system are propagated as deletes (requires [delete tracker registration](#step-5-register-delete-trackers)).

| Object Name | Description | Primary Key |
|---|---|---|
| `generalLedgerAccounts` | Chart of accounts / general ledger accounts | `systemId` |
| `bankAccounts` | Bank accounts | `systemId` |
| `contacts` | CRM contacts | `systemId` |
| `countriesRegions` | Country and region codes | `systemId` |
| `currencies` | Currency definitions | `systemId` |
| `currencyExchangeRates` | Exchange rate history | `systemId` |
| `customers` | Customer master data | `systemId` |
| `generalJournalBatches` | General journal batch headers | `systemId` |
| `reasonCodes` | Reason codes for transactions | `systemId` |
| `generalJournalLines` | Open general journal line entries | `systemId` |
| `defaultDimensions` | Default dimension assignments | `systemId` |
| `dimensionValues` | Dimension value definitions | `systemId` |
| `dimensions` | Dimension definitions | `systemId` |
| `employees` | Employee records | `systemId` |
| `generalProductPostingGroups` | Product posting group setup | `systemId` |
| `vendors` | Vendor master data | `systemId` |
| `inventoryPostingGroups` | Inventory posting group setup | `systemId` |
| `itemCategories` | Item category hierarchy | `systemId` |
| `itemVariants` | Item variant definitions | `systemId` |
| `items` | Item (product) master data | `systemId` |
| `locations` | Warehouse / location records | `systemId` |
| `opportunities` | CRM opportunities | `systemId` |
| `paymentMethods` | Payment method codes | `systemId` |
| `paymentTerms` | Payment term definitions | `systemId` |
| `purchaseLines` | Open purchase order/invoice lines | `systemId` |
| `jobs` | Projects / jobs | `systemId` |
| `shipmentMethods` | Shipment method codes | `systemId` |
| `unitsOfMeasure` | Unit of measure definitions | `systemId` |
| `timeSheetDetails` | Time sheet detail records | `systemId` |
| `salesHeaders` | Open sales order/invoice headers | `systemId` |
| `salesLines` | Open sales order/invoice lines | `systemId` |
| `purchaseHeaders` | Open purchase order/invoice headers | `systemId` |

### Additional CDC Object (No Deletes)

| Object Name | Description | Primary Key | Cursor Field |
|---|---|---|---|
| `companyInformation` | Company details (address, tax, etc.) | `systemId` | `systemModifiedAt` |

### Posted / Immutable Objects (Append-Only)

These objects contain posted (immutable) records that are never modified after creation. New records are ingested incrementally via `systemCreatedAt`.

| Object Name | Description | Primary Key |
|---|---|---|
| `generalLedgerEntries` | Posted general ledger entries | `systemId` |
| `itemLedgerEntries` | Posted item ledger entries | `systemId` |
| `purchaseReceiptLines` | Posted purchase receipt lines | `systemId` |
| `salesCreditMemoLines` | Posted sales credit memo lines | `systemId` |
| `purchaseReceiptHeaders` | Posted purchase receipt headers | `systemId` |
| `salesCreditMemoHeaders` | Posted sales credit memo headers | `systemId` |
| `salesShipmentLines` | Posted sales shipment lines | `systemId` |
| `salesShipmentHeaders` | Posted sales shipment headers | `systemId` |
| `postedGeneralJournalBatch` | Posted journal batch headers | `systemId` |
| `postedGeneralJournalLines` | Posted journal line entries | `systemId` |
| `purchaseInvoiceHeaders` | Posted purchase invoice headers | `systemId` |
| `purchaseInvoiceLines` | Posted purchase invoice lines | `systemId` |
| `salesInvoiceHeaders` | Posted sales invoice headers | `systemId` |
| `salesInvoiceLines` | Posted sales invoice lines | `systemId` |

### High-Volume Snapshot Objects

| Object Name | Description | Primary Key |
|---|---|---|
| `rawCompanies` | Company list (for multi-company discovery) | `systemId` |
| `dimensionSetEntries` | Dimension set entry combinations | `systemId` |


## How Delete Tracking Works

Unlike webhook-based approaches (e.g., Fivetran's delete subscription model which POSTs to an external URL on each delete), this connector uses a **pull-based** delete tracking mechanism:

1. **Delete Tracker table** — Stores which BC tables are tracked for deletes. You register a tracker entry per table per company.
2. **Deleted Record table** — When a tracked record is deleted, the AL extension's `DeleteEventHandler` codeunit intercepts the `OnDatabaseDelete` event and writes a tombstone entry containing the deleted record's `systemId`, the source table ID, and a timestamp.
3. **Connector reads incrementally** — The connector queries the `deletedRecords` API endpoint filtered by table ID and timestamp, then emits delete operations to Databricks via `apply_changes` with `apply_as_deletes`.

**Advantages over webhook-based deletes:**
- No inbound network access required (no public URL or firewall rules).
- Works in air-gapped or restricted network environments.
- Delete events are persisted in BC and can be re-read if the pipeline is restarted.

**Maintenance:** The `Deleted Record` table in BC grows over time. Consider setting up a scheduled BC job to purge entries older than 30–90 days to prevent unbounded growth.


## Table Configurations

### Source & Destination

These are set directly under each `table` object in the pipeline spec:

| Option | Required | Description |
|---|---|---|
| `source_table` | Yes | Table name in the source system (must match an object name listed above) |
| `destination_catalog` | No | Target catalog (defaults to pipeline's default) |
| `destination_schema` | No | Target schema (defaults to pipeline's default) |
| `destination_table` | No | Target table name (defaults to `source_table`) |

### Common `table_configuration` options

These are set inside the `table_configuration` map alongside any source-specific options:

| Option | Required | Description |
|---|---|---|
| `scd_type` | No | `SCD_TYPE_1` (default) or `SCD_TYPE_2`. Only applicable to tables with CDC or SNAPSHOT ingestion mode; APPEND_ONLY tables do not support this option. |
| `primary_keys` | No | List of columns to override the connector's default primary keys |
| `sequence_by` | No | Column used to order records for SCD Type 2 change tracking |

### Tuning options

| Option | Required | Default | Description |
|---|---|---|---|
| `max_records_per_batch` | No | `200` | Maximum number of records returned per micro-batch. Controls memory usage and Spark task size. Use smaller values for high-volume tables. |
| `window_seconds` | No | `3600` | Size of the sliding time-window (in seconds) used to scope incremental queries. Smaller windows reduce per-request latency but require more iterations. Relevant for all incremental (CDC and append) tables. |


## Data Type Mapping

| Business Central Type | OData Type | Databricks Type |
|---|---|---|
| Code, Text | `Edm.String` | `STRING` |
| GUID | `Edm.Guid` | `STRING` |
| Integer | `Edm.Int32` | `BIGINT` |
| BigInteger | `Edm.Int64` | `BIGINT` |
| Decimal | `Edm.Decimal` | `DECIMAL(38,10)` |
| Double | `Edm.Double` | `DECIMAL(38,10)` |
| Boolean | `Edm.Boolean` | `BOOLEAN` |
| Date | `Edm.Date` | `STRING` (format: `YYYY-MM-DD`) |
| DateTime | `Edm.DateTimeOffset` | `STRING` (ISO 8601 with timezone) |
| DateFormula | `Edm.Duration` | `STRING` (ISO 8601 duration) |
| Media, Blob | `Edm.Stream` | `STRING` |
| Option, Enum | Enum | `STRING` (value name) |

Schemas are discovered dynamically from the Business Central OData `$metadata` endpoint at runtime.


## Running the Pipeline

### Example Pipeline Spec

```json
{
  "connection_name": "my_bc_connection",
  "objects": [
    {
      "table": {
        "source_table": "customers",
        "table_configuration": {
          "max_records_per_batch": "500",
          "window_seconds": "3600"
        }
      }
    },
    {
      "table": {
        "source_table": "generalLedgerEntries",
        "table_configuration": {
          "max_records_per_batch": "200",
          "window_seconds": "1800"
        }
      }
    },
    {
      "table": {
        "source_table": "salesInvoiceHeaders"
      }
    }
  ]
}
```

### Best Practices

- **Start small:** Begin by syncing a few key objects (e.g. `customers`, `items`, `generalLedgerEntries`) to validate connectivity before adding all 51 objects.
- **Use incremental sync:** Most objects support CDC or append-only ingestion, which dramatically reduces API calls compared to full refresh.
- **Tune `window_seconds` for high-volume tables:** For tables like `generalLedgerEntries` or `itemLedgerEntries` that may have millions of records, use a smaller value (e.g. `600`) to keep each API request bounded.
- **Respect API rate limits:** Business Central allows up to 6,000 requests per minute per environment and 5 concurrent requests. The connector includes automatic retry with exponential backoff for HTTP 429 responses, but avoid scheduling too many pipelines against the same environment simultaneously.
- **Register delete trackers before going live:** Deletes are only captured after tracker registration. Register all trackers during initial setup to avoid missing deletions.
- **Run a full refresh after registering trackers** if records were deleted before registration. This ensures the destination tables match the current state of Business Central.
- **Maintain the delete log:** The `deletedRecords` table in Business Central grows over time. Set up a scheduled job to purge entries older than 30–90 days to prevent unbounded growth.


## Troubleshooting

| Issue | Cause | Resolution |
|---|---|---|
| `HTTP 401 Unauthorized` | Token expired or invalid app permissions | Verify the Azure AD app has `API.ReadWrite.All` permission with admin consent. Check that the client secret has not expired. |
| `HTTP 403 Forbidden` on delete tracker registration | Missing `CONNECTOR_SETUP` permission set | In BC, go to **Microsoft Entra Applications**, find your app, and add the `CONNECTOR_SETUP` permission set. See [Step 3](#step-3-authorize-the-app-in-business-central). |
| `HTTP 404 Not Found` | Incorrect environment name, missing AL extension, or wrong company ID | Verify the `environment` parameter matches exactly (e.g. `Production`). Confirm the AL extension is published and installed. Validate `company_id` via the `rawCompanies` object. |
| `HTTP 429 Too Many Requests` | API rate limit exceeded | The connector automatically retries with exponential backoff. If persistent, reduce pipeline concurrency or increase `window_seconds` to reduce request volume. |
| Queries timing out on large tables | Unbounded query scanning too many records | Decrease `window_seconds` (e.g. to `300` or `60`) and reduce `max_records_per_batch` to keep each request small. |
| Deletes not being captured | Delete trackers not registered | Register delete trackers for each table. See [Step 5](#step-5-register-delete-trackers). Only deletes occurring after registration are tracked. |
| Stale records remain after deletes | Records deleted before tracker registration | Run a **Full Refresh** on the pipeline to rebuild destination tables from the current state of Business Central. |
| AL extension not visible in Web Services | Extension not published or installed | Republish the extension from VS Code (Ctrl+F5), or check **Extension Management** in BC to verify the extension status is "Installed". |


## References

| Resource | URL |
|---|---|
| Business Central Custom API Pages | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api |
| Business Central API Rate Limits | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/operational-limits-online |
| Business Central OData Filtering | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-connect-apps-filtering |
| Business Central OAuth 2.0 Authentication | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-connect-apps |
| Azure AD App Registration | https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app |
| AL Language Extension for VS Code | https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al |
