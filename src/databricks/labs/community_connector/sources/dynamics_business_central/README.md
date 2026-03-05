# Lakeflow Microsoft Dynamics 365 Business Central Community Connector

This documentation provides setup instructions and reference information for the Microsoft Dynamics 365 Business Central source connector.

## Prerequisites

- A **Dynamics 365 Business Central** environment (Production or Sandbox) with API access enabled.
- An **Azure AD (Entra ID) app registration** with the `https://api.businesscentral.dynamics.com/.default` API permission granted (admin-consented).
- A **client secret** created for the app registration.
- The custom **AL extension** (`initialSetup_databricks.al`) deployed to the target Business Central environment. This extension exposes the OData API pages and delete-tracking infrastructure that the connector reads from.
- The Business Central **company ID** (GUID) for the company you want to ingest data from.

## Setup

### Required Connection Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `tenant_id` | string | Yes | Azure AD tenant ID (GUID). Found on the app registration Overview page, or in your Business Central URL (`https://businesscentral.dynamics.com/{tenant_id}/`). |
| `client_id` | string | Yes | Application (client) ID (GUID). Found on the app registration Overview page. |
| `client_secret` | string (secret) | Yes | Client secret value from the app registration's Certificates & secrets page. |
| `environment` | string | Yes | Business Central environment name, e.g. `Production` or `Sandbox`. |
| `company_id` | string | Yes | Business Central company ID (GUID). See [Finding Your Company ID](#finding-your-company-id) below. |
| `externalOptionsAllowList` | string | Yes | Must be set to `max_records_per_batch,window_seconds` to enable per-table tuning options. |

### Creating the Azure AD App Registration

1. Go to the [Azure Portal](https://portal.azure.com/) > **Azure Active Directory** > **App registrations** > **New registration**.
2. Give the app a name (e.g. "Databricks BC Connector") and register it.
3. On the app's **Overview** page, copy the **Application (client) ID** and the **Directory (tenant) ID**.
4. Go to **API permissions** > **Add a permission** > **APIs my organization uses** > search for `Dynamics 365 Business Central` > select **Application permissions** > add `API.ReadWrite.All`. Click **Grant admin consent**.
5. Go to **Certificates & secrets** > **New client secret**. Copy the secret **Value** (not the Secret ID).
6. In Business Central, ensure the app has the correct permissions assigned to access company data.

### Finding Your Company ID

The company ID is a GUID identifying the specific Business Central company to ingest. You can find it by:

- Navigating to the `rawCompanies` table after the connector is set up (it lists all companies).
- Checking the Business Central web client URL, which includes the company ID.
- Using the OData endpoint directly:
  ```
  GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies
  ```

### Deploying the AL Extension

Before the connector can read data, the custom AL extension must be deployed to your Business Central environment. This extension:
- Creates custom API pages that expose table data via OData.
- Sets up the delete-tracking infrastructure (log table, event handler, tracker registration).

Publish and install the extension using the AL Language extension in Visual Studio Code, or deploy it via the Business Central Extension Management page.

### Create a Unity Catalog Connection

A Unity Catalog connection for this connector can be created in two ways via the UI:
1. Follow the Lakeflow Community Connector UI flow from the "Add Data" page.
2. Select any existing Lakeflow Community Connector connection for this source or create a new one.
3. Set the `externalOptionsAllowList` to `max_records_per_batch,window_seconds` to allow per-table configuration of batch size and time-window scope.

The connection can also be created using the standard Unity Catalog API.


## Supported Objects

This connector supports **51 objects** organized into three categories. Object names are case-sensitive and must be specified exactly as shown.

### Metadata Objects (Snapshot)

These objects are refreshed fully on each run.

| Object Name | Description | Primary Key |
|---|---|---|
| `pageMetadata` | Metadata about API pages deployed in the system | `id` |
| `tableMetadata` | Metadata about tables in the system | `id` |

### Master Data & Setup Objects (CDC with Deletes)

These objects support incremental ingestion via `systemModifiedAt` and delete synchronization. Records that are modified or created since the last sync are captured; records deleted from the source system are propagated as deletes.

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

**Delete tracking:** Deletes are captured via a custom AL extension that logs delete events into a `deletedRecords` table within Business Central. When a record is deleted from a tracked table, the event handler writes a tombstone entry. The connector reads these entries incrementally to propagate deletes to Databricks.

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

### Special `table_configuration` options

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


## How to Run

### Step 1: Clone/Copy the Source Connector Code
Follow the Lakeflow Community Connector UI, which will guide you through setting up a pipeline using the selected source connector code.

### Step 2: Configure Your Pipeline

1. Update the `pipeline_spec` in the main pipeline file (e.g., `ingest.py`).
2. Add each object you want to ingest as a table entry. Use `table_configuration` to tune batch size and window scope per table:

```json
{
  "pipeline_spec": {
    "connection_name": "my_bc_connection",
    "object": [
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
}
```

3. (Optional) Customize the source connector code if needed for special use cases.

### Step 3: Run and Schedule the Pipeline

#### Best Practices

- **Start Small**: Begin by syncing a few key objects (e.g. `customers`, `items`, `generalLedgerEntries`) to validate connectivity before adding all 51 objects.
- **Use Incremental Sync**: Most objects support CDC or append-only ingestion, which dramatically reduces API calls compared to full refresh.
- **Tune `window_seconds` for High-Volume Tables**: For tables like `generalLedgerEntries` or `itemLedgerEntries` that may have millions of records, use a smaller `window_seconds` (e.g. `600`) to keep each API request bounded.
- **Respect API Rate Limits**: Business Central allows up to 6,000 requests per minute per environment and 5 concurrent requests. The connector includes automatic retry with exponential backoff for HTTP 429 responses, but avoid scheduling too many pipelines against the same environment simultaneously.
- **Deploy Delete Trackers**: For tables with delete synchronization, ensure the delete tracker registrations are created in Business Central. The connector can auto-register trackers on first use.
- **Maintain the Delete Log**: The `deletedRecords` log table in Business Central grows over time. Set up a scheduled job to purge entries older than 30 days to prevent unbounded growth.

#### Troubleshooting

**Common Issues:**

| Issue | Cause | Resolution |
|---|---|---|
| `HTTP 401 Unauthorized` | Token expired or invalid app permissions | Verify the Azure AD app has `API.ReadWrite.All` permission with admin consent. Check that the client secret has not expired. |
| `HTTP 404 Not Found` | Incorrect environment name, missing AL extension, or wrong company ID | Verify the `environment` parameter matches exactly (e.g. `Production`). Confirm the AL extension is published and installed. Validate `company_id` via the `rawCompanies` object. |
| `HTTP 429 Too Many Requests` | API rate limit exceeded | The connector automatically retries with exponential backoff. If persistent, reduce pipeline concurrency or increase `window_seconds` to reduce request volume. |
| Queries timing out on large tables | Unbounded query scanning too many records | Decrease `window_seconds` (e.g. to `300` or `60`) and reduce `max_records_per_batch` to keep each request small. |
| Deletes not being captured | Delete trackers not registered | Ensure the AL extension is deployed and the delete tracker registrations exist for each tracked table. The `deleteTrackers` object lists active registrations. |


## References

| Resource | URL |
|---|---|
| Business Central Custom API Pages | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api |
| Business Central API Rate Limits | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/operational-limits-online |
| Business Central OData Filtering | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-connect-apps-filtering |
| Business Central OAuth 2.0 Authentication | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-connect-apps |
| Azure AD App Registration | https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app |
