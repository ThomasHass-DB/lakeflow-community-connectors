# Dynamics 365 Business Central API Documentation

## Authorization

Business Central exposes custom API pages via OData v4 endpoints. Authentication uses **OAuth 2.0 Client Credentials** flow (service-to-service).

### OAuth 2.0 Client Credentials Flow (Preferred)

**Required parameters:**
| Parameter | Description |
|-----------|-------------|
| `tenant_id` | Azure AD tenant ID (GUID) |
| `client_id` | Azure AD application (client) ID |
| `client_secret` | Azure AD application client secret |
| `environment` | Business Central environment name (e.g., `Production`, `Sandbox`) |
| `company_id` | Business Central company ID (GUID). Can be retrieved dynamically via the `rawCompanies` endpoint. |

**Token endpoint:**
```
POST https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={client_id}
&client_secret={client_secret}
&scope=https://api.businesscentral.dynamics.com/.default
```

**Response:**
```json
{
  "access_token": "eyJ0eX...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Using the token in API requests:**
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/customers
Authorization: Bearer {access_token}
```

### Alternative: Web Service Access Key (Basic Auth)

Not recommended for production. Uses `username` and `web_service_access_key` as Basic Auth credentials.

### Base URL Structure

All custom API endpoints in this connector follow this pattern:

```
https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/{apiPublisher}/{apiGroup}/{apiVersion}/companies({company_id})/{entitySetName}
```

Where:
- `apiPublisher` = `databricks` (for all pages in this connector)
- `apiGroup` = `metadata` or `standardEndpoints`
- `apiVersion` = `v1.0`

**Example:**
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/customers
Authorization: Bearer {access_token}
```

**Response format (OData v4):**
```json
{
  "@odata.context": "...",
  "value": [
    { "systemId": "...", "no": "10000", "name": "Adatum Corporation", ... },
    { "systemId": "...", "no": "20000", "name": "Trey Research", ... }
  ],
  "@odata.nextLink": "...?$skip=..."
}
```

---

## Object List

The object list is **static**, derived from the custom AL API pages deployed as an extension. There are **51 API pages** across two API groups.

### Metadata Group (`api/databricks/metadata/v1.0`)

These endpoints are **not scoped to a company** — call them without the `companies({company_id})/` segment:

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/metadata/v1.0/{entitySetName}
```

| # | Page ID | Entity Set Name | Source Table | Description |
|---|---------|-----------------|--------------|-------------|
| 1 | 90001 | `pageMetadata` | Page Metadata | Metadata about API pages deployed in the system |
| 2 | 90002 | `tableMetadata` | Table Metadata | Metadata about tables in the system |

### Delete Tracking Group (`api/databricks/deleteTracking/v1.0`)

These endpoints are **not scoped to a company** (the underlying tables have `DataPerCompany = false`):

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/deleteTracking/v1.0/{entitySetName}
```

| # | Page ID | Entity Set Name | Source Table | Description |
|---|---------|-----------------|--------------|-------------|
| — | 90100 | `deletedRecords` | Databricks Deleted Record | Log of all deleted records (pull-based delete tracking) |
| — | 90101 | `deleteTrackers` | Delete Tracker | Registers which tables to track for deletes |

### Standard Endpoints Group (`api/databricks/standardEndpoints/v1.0`)

These are **company-scoped**:

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/{entitySetName}
```

| # | Page ID | Entity Set Name | Source Table | Description |
|---|---------|-----------------|--------------|-------------|
| 3 | 90003 | `generalLedgerAccounts` | G/L Account | Chart of accounts / general ledger accounts |
| 4 | 90004 | `bankAccounts` | Bank Account | Bank accounts |
| 5 | 90005 | `companyInformation` | Company Information | Company details (address, tax, etc.) |
| 6 | 90006 | `contacts` | Contact | CRM contacts |
| 7 | 90007 | `countriesRegions` | Country/Region | Country and region codes |
| 8 | 90008 | `currencies` | Currency | Currency definitions and exchange info |
| 9 | 90009 | `currencyExchangeRates` | Currency Exchange Rate | Exchange rate history |
| 10 | 90010 | `customers` | Customer | Customer master data |
| 11 | 90011 | `generalJournalBatches` | Gen. Journal Batch | General journal batch headers |
| 12 | 90012 | `reasonCodes` | Reason Code | Reason codes for transactions |
| 13 | 90013 | `generalJournalLines` | Gen. Journal Line | General journal line entries |
| 14 | 90014 | `defaultDimensions` | Default Dimension | Default dimension assignments |
| 15 | 90015 | `dimensionValues` | Dimension Value | Dimension value definitions |
| 16 | 90016 | `dimensions` | Dimension | Dimension definitions |
| 17 | 90017 | `employees` | Employee | Employee records |
| 18 | 90018 | `generalLedgerEntries` | G/L Entry | Posted general ledger entries |
| 19 | 90019 | `generalProductPostingGroups` | Gen. Product Posting Group | Product posting group setup |
| 20 | 90020 | `vendors` | Vendor | Vendor master data |
| 21 | 90021 | `inventoryPostingGroups` | Inventory Posting Group | Inventory posting group setup |
| 22 | 90022 | `itemCategories` | Item Category | Item category hierarchy |
| 23 | 90023 | `itemLedgerEntries` | Item Ledger Entry | Posted item ledger entries |
| 24 | 90024 | `itemVariants` | Item Variant | Item variant definitions |
| 25 | 90025 | `items` | Item | Item (product) master data |
| 26 | 90026 | `locations` | Location | Warehouse/location records |
| 27 | 90027 | `opportunities` | Opportunity | CRM opportunities |
| 28 | 90028 | `paymentMethods` | Payment Method | Payment method codes |
| 29 | 90029 | `paymentTerms` | Payment Terms | Payment term definitions |
| 30 | 90030 | `purchaseReceiptLines` | Purch. Rcpt. Line | Posted purchase receipt lines |
| 31 | 90031 | `salesCreditMemoLines` | Sales Cr.Memo Line | Posted sales credit memo lines |
| 32 | 90032 | `purchaseReceiptHeaders` | Purch. Rcpt. Header | Posted purchase receipt headers |
| 33 | 90033 | `jobs` | Job | Projects / jobs |
| 34 | 90034 | `rawCompanies` | Company | Company list (for multi-company discovery) |
| 35 | 90035 | `salesCreditMemoHeaders` | Sales Cr.Memo Header | Posted sales credit memo headers |
| 36 | 90036 | `purchaseLines` | Purchase Line | Open purchase order/invoice lines |
| 37 | 90037 | `salesShipmentLines` | Sales Shipment Line | Posted sales shipment lines |
| 38 | 90038 | `salesShipmentHeaders` | Sales Shipment Header | Posted sales shipment headers |
| 39 | 90039 | `shipmentMethods` | Shipment Method | Shipment method codes |
| 40 | 90040 | `unitsOfMeasure` | Unit of Measure | Unit of measure definitions |
| 41 | 90041 | `postedGeneralJournalBatch` | Posted Gen. Journal Batch | Posted journal batch headers |
| 42 | 90042 | `postedGeneralJournalLines` | Posted Gen. Journal Line | Posted journal line entries |
| 43 | 90043 | `purchaseInvoiceHeaders` | Purch. Inv. Header | Posted purchase invoice headers |
| 44 | 90044 | `purchaseInvoiceLines` | Purch. Inv. Line | Posted purchase invoice lines |
| 45 | 90045 | `timeSheetDetails` | Time Sheet Detail | Time sheet detail records |
| 46 | 90046 | `salesHeaders` | Sales Header | Open sales order/invoice headers |
| 47 | 90047 | `salesLines` | Sales Line | Open sales order/invoice lines |
| 48 | 90048 | `salesInvoiceHeaders` | Sales Invoice Header | Posted sales invoice headers |
| 49 | 90049 | `salesInvoiceLines` | Sales Invoice Line | Posted sales invoice lines |
| 50 | 90050 | `purchaseHeaders` | Purchase Header | Open purchase order/invoice headers |
| 51 | 90051 | `dimensionSetEntries` | Dimension Set Entry | Dimension set entry combinations |

---

## Object Schema

### Schema Retrieval

Schemas are **static** — they are defined by the AL page fields. There is no schema discovery API. The fields for each entity are fixed by the deployed extension code.

Each page exposes a specific set of fields from its source table. The OData `$metadata` endpoint can be used to introspect the schema at runtime:

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/$metadata
```

This returns an EDMX document describing all entity types and their properties.

### Common System Fields

Every entity includes these system-tracked fields:

| Field Name | Type | Description |
|------------|------|-------------|
| `systemId` | Edm.Guid | Unique record identifier (GUID). Primary key for OData. |
| `systemCreatedAt` | Edm.DateTimeOffset | Record creation timestamp (UTC) |
| `systemCreatedBy` | Edm.Guid | User who created the record |
| `systemModifiedAt` | Edm.DateTimeOffset | Last modification timestamp (UTC) |
| `systemModifiedBy` | Edm.Guid | User who last modified the record |

### Per-Entity Schemas

Below are the fields for each entity, as defined in the AL page source code. The `field(apiFieldName; Rec.SourceField)` AL syntax means the JSON property name in the OData response is the `apiFieldName`.

#### Delete Tracking: `deletedRecords`

| API Field Name | Source Field | Caption |
|---------------|-------------|---------|
| `entryNo` | Entry No. | Entry No. |
| `tableId` | Table ID | Table ID |
| `companyId` | Company ID | Company ID |
| `deletedSystemId` | Deleted System ID | Deleted System ID |
| `recordPosition` | Record Position | Record Position |
| `deletedAt` | Deleted At | Deleted At |
| `systemModifiedAtOriginal` | Original System Modified At | Original System Modified At |
| `systemCreatedAt` | SystemCreatedAt | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy | SystemCreatedBy |
| `systemId` | SystemId | SystemId |
| `systemModifiedAt` | SystemModifiedAt | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy | SystemModifiedBy |

#### Delete Tracking: `deleteTrackers`

| API Field Name | Source Field | Caption |
|---------------|-------------|---------|
| `id` | Id | Id |
| `tableId` | Table ID | Table ID |
| `companyId` | Company ID | Company ID |
| `recordsDeleted` | Records Deleted | Records Deleted |
| `systemCreatedAt` | SystemCreatedAt | SystemCreatedAt |
| `systemModifiedAt` | SystemModifiedAt | SystemModifiedAt |
| `systemId` | SystemId | SystemId |

#### 1. `pageMetadata` (Metadata Group)

| API Field Name | Source Field | Caption |
|---------------|-------------|---------|
| `apiGroup` | APIGroup | APIGroup |
| `apiPublisher` | APIPublisher | APIPublisher |
| `apiVersion` | APIVersion | APIVersion |
| `autoSplitKey` | AutoSplitKey | AutoSplitKey |
| `caption` | Caption | Caption |
| `cardPageID` | CardPageID | CardPageID |
| `changeTrackingAllowed` | ChangeTrackingAllowed | ChangeTrackingAllowed |
| `dataCaptionExpr` | DataCaptionExpr. | DataCaptionExpr. |
| `dataCaptionFields` | DataCaptionFields | DataCaptionFields |
| `delayedInsert` | DelayedInsert | DelayedInsert |
| `deleteAllowed` | DeleteAllowed | DeleteAllowed |
| `editable` | Editable | Editable |
| `entityName` | EntityName | EntityName |
| `entitySetName` | EntitySetName | EntitySetName |
| `id` | ID | ID |
| `insertAllowed` | InsertAllowed | InsertAllowed |
| `linksAllowed` | LinksAllowed | LinksAllowed |
| `modifyAllowed` | ModifyAllowed | ModifyAllowed |
| `multipleNewLines` | MultipleNewLines | MultipleNewLines |
| `name` | Name | Name |
| `pageType` | PageType | PageType |
| `populateAllFields` | PopulateAllFields | PopulateAllFields |
| `refreshOnActivate` | RefreshOnActivate | RefreshOnActivate |
| `saveValues` | SaveValues | SaveValues |
| `showFilter` | ShowFilter | ShowFilter |
| `sourceTable` | SourceTable | SourceTable |
| `sourceTableTemporary` | SourceTableTemporary | SourceTableTemporary |
| `sourceTableView` | SourceTableView | SourceTableView |
| `systemCreatedAt` | SystemCreatedAt | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy | SystemCreatedBy |
| `systemId` | SystemId | SystemId |
| `systemModifiedAt` | SystemModifiedAt | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy | SystemModifiedBy |

#### 2. `tableMetadata` (Metadata Group)

| API Field Name | Source Field | Caption |
|---------------|-------------|---------|
| `caption` | Caption | Caption |
| `compressionType` | CompressionType | CompressionType |
| `dataCaptionFields` | DataCaptionFields | DataCaptionFields |
| `dataClassification` | DataClassification | DataClassification |
| `dataIsExternal` | DataIsExternal | DataIsExternal |
| `dataPerCompany` | DataPerCompany | DataPerCompany |
| `drillDownPageId` | DrillDownPageId | DrillDownPageId |
| `externalName` | ExternalName | ExternalName |
| `id` | ID | ID |
| `linkedObject` | LinkedObject | LinkedObject |
| `lookupPageID` | LookupPageID | LookupPageID |
| `name` | Name | Name |
| `obsoleteReason` | ObsoleteReason | ObsoleteReason |
| `obsoleteState` | ObsoleteState | ObsoleteState |
| `pasteIsValid` | PasteIsValid | PasteIsValid |
| `replicateData` | ReplicateData | ReplicateData |
| `systemCreatedAt` | SystemCreatedAt | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy | SystemCreatedBy |
| `systemId` | SystemId | SystemId |
| `systemModifiedAt` | SystemModifiedAt | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy | SystemModifiedBy |
| `tableType` | TableType | TableType |

#### 3. `generalLedgerAccounts`

| API Field Name | Source Field | Caption |
|---------------|-------------|---------|
| `apiAccountType` | API Account Type | API Account Type |
| `accountCategory` | Account Category | Account Category |
| `accountSubcategoryDescript` | Account Subcategory Descript. | Account Subcategory Descript. |
| `accountSubcategoryEntryNo` | Account Subcategory Entry No. | Account Subcategory Entry No. |
| `accountType` | Account Type | Account Type |
| `addCurrencyBalanceAtDate` | Add.-Currency Balance at Date | Add.-Currency Balance at Date |
| `addCurrencyCreditAmount` | Add.-Currency Credit Amount | Add.-Currency Credit Amount |
| `addCurrencyDebitAmount` | Add.-Currency Debit Amount | Add.-Currency Debit Amount |
| `additionalCurrencyBalance` | Additional-Currency Balance | Additional-Currency Balance |
| `additionalCurrencyNetChange` | Additional-Currency Net Change | Additional-Currency Net Change |
| `automaticExtTexts` | Automatic Ext. Texts | Automatic Ext. Texts |
| `balance` | Balance | Balance |
| `balanceAtDate` | Balance at Date | Balance at Date |
| `blocked` | Blocked | Blocked |
| `budgetAtDate` | Budget at Date | Budget at Date |
| `budgetedAmount` | Budgeted Amount | Budgeted Amount |
| `budgetedCreditAmount` | Budgeted Credit Amount | Budgeted Credit Amount |
| `budgetedDebitAmount` | Budgeted Debit Amount | Budgeted Debit Amount |
| `comment` | Comment | Comment |
| `consolCreditAcc` | Consol. Credit Acc. | Consol. Credit Acc. |
| `consolDebitAcc` | Consol. Debit Acc. | Consol. Debit Acc. |
| `consolTranslationMethod` | Consol. Translation Method | Consol. Translation Method |
| `costTypeNo` | Cost Type No. | Cost Type No. |
| `creditAmount` | Credit Amount | Credit Amount |
| `debitAmount` | Debit Amount | Debit Amount |
| `debitCredit` | Debit/Credit | Debit/Credit |
| `defaultDeferralTemplateCode` | Default Deferral Template Code | Default Deferral Template Code |
| `defaultICPartnerGLAccNo` | Default IC Partner G/L Acc. No | Default IC Partner G/L Acc. No |
| `directPosting` | Direct Posting | Direct Posting |
| `exchangeRateAdjustment` | Exchange Rate Adjustment | Exchange Rate Adjustment |
| `gifiCode` | GIFI Code | GIFI Code |
| `genBusPostingGroup` | Gen. Bus. Posting Group | Gen. Bus. Posting Group |
| `genPostingType` | Gen. Posting Type | Gen. Posting Type |
| `genProdPostingGroup` | Gen. Prod. Posting Group | Gen. Prod. Posting Group |
| `globalDimension1Code` | Global Dimension 1 Code | Global Dimension 1 Code |
| `globalDimension2Code` | Global Dimension 2 Code | Global Dimension 2 Code |
| `incomeBalance` | Income/Balance | Income/Balance |
| `indentation` | Indentation | Indentation |
| `lastDateModified` | Last Date Modified | Last Date Modified |
| `lastModifiedDateTime` | Last Modified Date Time | Last Modified Date Time |
| `name` | Name | Name |
| `netChange` | Net Change | Net Change |
| `newPage` | New Page | New Page |
| `no` | No. | No. |
| `no2` | No. 2 | No. 2 |
| `noOfBlankLines` | No. of Blank Lines | No. of Blank Lines |
| `omitDefaultDescrInJnl` | Omit Default Descr. in Jnl. | Omit Default Descr. in Jnl. |
| `picture` | Picture | Picture |
| `reconciliationAccount` | Reconciliation Account | Reconciliation Account |
| `satAccountCode` | SAT Account Code | SAT Account Code |
| `searchName` | Search Name | Search Name |
| `systemCreatedAt` | SystemCreatedAt | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy | SystemCreatedBy |
| `systemId` | SystemId | SystemId |
| `systemModifiedAt` | SystemModifiedAt | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy | SystemModifiedBy |
| `taxAreaCode` | Tax Area Code | Tax Area Code |
| `taxGroupCode` | Tax Group Code | Tax Group Code |
| `taxLiable` | Tax Liable | Tax Liable |
| `totaling` | Totaling | Totaling |
| `vatAmt` | VAT Amt. | VAT Amt. |
| `vatBusPostingGroup` | VAT Bus. Posting Group | VAT Bus. Posting Group |
| `vatProdPostingGroup` | VAT Prod. Posting Group | VAT Prod. Posting Group |
| `budgetFilter` | Budget Filter | Budget Filter |
| `businessUnitFilter` | Business Unit Filter | Business Unit Filter |
| `dateFilter` | Date Filter | Date Filter |
| `dimensionSetIDFilter` | Dimension Set ID Filter | Dimension Set ID Filter |
| `globalDimension1Filter` | Global Dimension 1 Filter | Global Dimension 1 Filter |
| `globalDimension2Filter` | Global Dimension 2 Filter | Global Dimension 2 Filter |
| `vatReportingDateFilter` | VAT Reporting Date Filter | VAT Reporting Date Filter |

#### 4. `bankAccounts`

Fields extracted from page 90004 (too many to list inline — see AL source lines 588–1002). Key fields include:
`systemId`, `no`, `name`, `searchName`, `bankAccountNo`, `bankBranchNo`, `contactPerson`, `balanceLCY`, `balance`, `blocked`, `currencyCode`, `iban`, `swiftCode`, `address`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `email`, `homePage`, `lastDateModified`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~80 additional fields covering bank-specific details, posting groups, intercompany info, and check printing settings.

#### 5. `companyInformation`

Fields from page 90005. Key fields: `systemId`, `name`, `name2`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `phoneNo2`, `faxNo`, `email`, `homePage`, `registrationNo`, `vatRegistrationNo`, `currencyCode`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~60 additional fields.

#### 6. `contacts`

Fields from page 90006. Key fields: `systemId`, `no`, `name`, `name2`, `companyName`, `companyNo`, `type`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `mobilePhoneNo`, `eMail`, `homePage`, `salespersonCode`, `lastDateModified`, `systemCreatedAt`, `systemModifiedAt`, plus ~80 additional fields.

#### 7. `countriesRegions`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `addressFormat` | Address Format |
| `code` | Code |
| `contactAddressFormat` | Contact Address Format |
| `countyName` | County Name |
| `euCountryRegionCode` | EU Country/Region Code |
| `ibanCountryRegionCode` | IBAN Country/Region Code |
| `intrastatCode` | Intrastat Code |
| `isoCode` | ISO Code |
| `isoNumericCode` | ISO Numeric Code |
| `lastModifiedDateTime` | Last Modified Date Time |
| `name` | Name |
| `satCountryCode` | SAT Country Code |
| `vatScheme` | VAT Scheme |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 8. `currencies`

Fields from page 90008. Key fields: `systemId`, `code`, `description`, `amountDecimalPlaces`, `amountRoundingPrecision`, `isoCode`, `isoNumericCode`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~30 additional fields covering rounding, exchange rate adjustments, and realized/unrealized gains/losses accounts.

#### 9. `currencyExchangeRates`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `currencyCode` | Currency Code |
| `exchangeRateAmount` | Exchange Rate Amount |
| `adjustmentExchRateAmount` | Adjustment Exch. Rate Amount |
| `fixExchangeRateAmount` | Fix Exchange Rate Amount |
| `relationalAdjmtExchRateAmt` | Relational Adjmt Exch Rate Amt |
| `relationalCurrencyCode` | Relational Currency Code |
| `relationalExchRateAmount` | Relational Exch. Rate Amount |
| `startingDate` | Starting Date |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 10. `customers`

Fields from page 90010. Key fields: `systemId`, `no`, `name`, `name2`, `searchName`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `eMail`, `homePage`, `contactPerson`, `balanceLCY`, `balance`, `balanceDue`, `balanceDueLCY`, `creditLimitLCY`, `blocked`, `currencyCode`, `customerPostingGroup`, `genBusPostingGroup`, `paymentTermsCode`, `paymentMethodCode`, `salespersonCode`, `lastDateModified`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~150 additional fields.

#### 11. `generalJournalBatches`

Fields from page 90011. Key fields: `systemId`, `journalTemplateName`, `name`, `description`, `balAccountType`, `balAccountNo`, `noSeries`, `postingNoSeries`, `reasonCode`, `copyVATSetupToJnlLines`, `allowVATDifference`, `allowPaymentExport`, `templateType`, `recurring`, `systemCreatedAt`, `systemModifiedAt`.

#### 12. `reasonCodes`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `code` | Code |
| `description` | Description |
| `lastModifiedDateTime` | Last Modified Date Time |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 13. `generalJournalLines`

Fields from page 90013. Very large schema (~180 fields). Key fields: `systemId`, `journalTemplateName`, `journalBatchName`, `lineNo`, `accountType`, `accountNo`, `postingDate`, `documentType`, `documentNo`, `description`, `amount`, `amountLCY`, `debitAmount`, `creditAmount`, `balAccountType`, `balAccountNo`, `currencyCode`, `dimensionSetID`, `systemCreatedAt`, `systemModifiedAt`.

#### 14. `defaultDimensions`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `allowedValuesFilter` | Allowed Values Filter |
| `dimensionCode` | Dimension Code |
| `dimensionValueCode` | Dimension Value Code |
| `multiSelectionAction` | Multi Selection Action |
| `parentType` | Parent Type |
| `tableCaption` | Table Caption |
| `tableID` | Table ID |
| `no` | No. |
| `valuePosting` | Value Posting |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 15. `dimensionValues`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `blocked` | Blocked |
| `code` | Code |
| `consolidationCode` | Consolidation Code |
| `dimensionCode` | Dimension Code |
| `dimensionValueID` | Dimension Value ID |
| `dimensionValueType` | Dimension Value Type |
| `globalDimensionNo` | Global Dimension No. |
| `indentation` | Indentation |
| `lastModifiedDateTime` | Last Modified Date Time |
| `mapToICDimensionCode` | Map-to IC Dimension Code |
| `mapToICDimensionValueCode` | Map-to IC Dimension Value Code |
| `name` | Name |
| `totaling` | Totaling |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 16. `dimensions`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `blocked` | Blocked |
| `code` | Code |
| `codeCaption` | Code Caption |
| `description` | Description |
| `filterCaption` | Filter Caption |
| `lastModifiedDateTime` | Last Modified Date Time |
| `mapToICDimensionCode` | Map-to IC Dimension Code |
| `name` | Name |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 17. `employees`

Fields from page 90017. Key fields: `systemId`, `no`, `firstName`, `middleName`, `lastName`, `initials`, `jobTitle`, `searchName`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `mobilePhoneNo`, `email`, `companyEMail`, `employmentDate`, `status`, `gender`, `birthDate`, `resourceNo`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~40 additional fields.

#### 18. `generalLedgerEntries`

Fields from page 90018. Key fields: `systemId`, `entryNo`, `gLAccountNo`, `postingDate`, `documentType`, `documentNo`, `description`, `amount`, `debitAmount`, `creditAmount`, `additionalCurrencyAmount`, `balAccountNo`, `balAccountType`, `dimensionSetID`, `gLAccountName`, `reversed`, `reversedByEntryNo`, `reversedEntryNo`, `sourceCode`, `sourceNo`, `sourceType`, `systemCreatedAt`, `systemModifiedAt`, plus ~40 additional fields.

#### 19. `generalProductPostingGroups`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `autoInsertDefault` | Auto Insert Default |
| `code` | Code |
| `defVATBusPostingGroup` | Def. VAT Bus. Posting Group |
| `description` | Description |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 20. `vendors`

Fields from page 90020. Key fields: `systemId`, `no`, `name`, `name2`, `searchName`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `eMail`, `homePage`, `contactPerson`, `balanceLCY`, `balance`, `balanceDue`, `balanceDueLCY`, `blocked`, `currencyCode`, `vendorPostingGroup`, `genBusPostingGroup`, `paymentTermsCode`, `paymentMethodCode`, `purchaserCode`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`, plus ~120 additional fields.

#### 21. `inventoryPostingGroups`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `code` | Code |
| `description` | Description |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 22. `itemCategories`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `code` | Code |
| `description` | Description |
| `hasChildren` | Has Children |
| `indentation` | Indentation |
| `lastModifiedDateTime` | Last Modified Date Time |
| `parentCategory` | Parent Category |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 23. `itemLedgerEntries`

Fields from page 90023. Key fields: `systemId`, `entryNo`, `itemNo`, `postingDate`, `entryType`, `sourceNo`, `sourceType`, `documentNo`, `documentType`, `description`, `locationCode`, `quantity`, `remainingQuantity`, `invoicedQuantity`, `costAmountActual`, `costAmountExpected`, `salesAmountActual`, `salesAmountExpected`, `globalDimension1Code`, `globalDimension2Code`, `dimensionSetID`, `lotNo`, `serialNo`, `open`, `systemCreatedAt`, `systemModifiedAt`, plus ~50 additional fields.

#### 24. `itemVariants`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `blocked` | Blocked |
| `code` | Code |
| `description` | Description |
| `description2` | Description 2 |
| `itemNo` | Item No. |
| `lastModifiedDateTime` | Last Modified Date Time |
| `salesBlocked` | Sales Blocked |
| `purchasingBlocked` | Purchasing Blocked |
| `serviceBlocked` | Service Blocked |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 25. `items`

Fields from page 90025. Very large schema (~180 fields). Key fields: `systemId`, `no`, `no2`, `description`, `description2`, `searchDescription`, `baseUnitOfMeasure`, `type`, `inventoryPostingGroup`, `genProdPostingGroup`, `itemCategoryCode`, `unitPrice`, `unitCost`, `standardCost`, `lastDirectCost`, `inventory`, `blocked`, `lastDateModified`, `lastModifiedDateTime`, `systemCreatedAt`, `systemModifiedAt`.

#### 26. `locations`

Fields from page 90026. Key fields: `systemId`, `code`, `name`, `name2`, `address`, `address2`, `city`, `postCode`, `countryRegionCode`, `phoneNo`, `faxNo`, `eMail`, `contact`, `useAsInTransit`, `requirePutAway`, `requirePick`, `requireReceive`, `requireShipment`, `binMandatory`, `directedPutAwayAndPick`, `defaultBinCode`, `systemCreatedAt`, `systemModifiedAt`, plus ~50 additional fields.

#### 27. `opportunities`

Fields from page 90027. Key fields: `systemId`, `no`, `description`, `salespersonCode`, `contactNo`, `contactCompanyNo`, `contactCompanyName`, `salesCycleCode`, `currentSalesCycleStage`, `status`, `closed`, `creationDate`, `dateClosed`, `priority`, `calcdCurrentValueLCY`, `chancesOfSuccessPerc`, `estimatedClosingDate`, `estimatedValueLCY`, `campaignNo`, `systemCreatedAt`, `systemModifiedAt`, plus ~20 additional fields.

#### 28. `paymentMethods`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `balAccountNo` | Bal. Account No. |
| `balAccountType` | Bal. Account Type |
| `code` | Code |
| `description` | Description |
| `directDebit` | Direct Debit |
| `directDebitPmtTermsCode` | Direct Debit Pmt. Terms Code |
| `lastModifiedDateTime` | Last Modified Date Time |
| `useForInvoicing` | Use for Invoicing |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 29. `paymentTerms`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `calcPmtDisc` | Calc. Pmt. Disc. on Cr. Memos |
| `code` | Code |
| `couponCode` | Coupon % |
| `description` | Description |
| `discount` | Discount % |
| `discountDateCalculation` | Discount Date Calculation |
| `dueDateCalculation` | Due Date Calculation |
| `lastModifiedDateTime` | Last Modified Date Time |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

#### 30–50. Remaining Entities

The remaining entities follow the same pattern. Each has fields extracted from the corresponding AL page definition. For the complete field list of any entity, refer to the AL source file at `initial_setup_periodic_reimport.al` at the page definition for that entity.

Key entities worth highlighting:

**`generalLedgerEntries` (page 90018)** — Very high-volume table. Key incremental field: `systemModifiedAt`. Append-only in practice (entries are not modified after posting).

**`itemLedgerEntries` (page 90023)** — High-volume table tracking inventory movements. Append-only in practice.

**`salesInvoiceHeaders` / `salesInvoiceLines` (pages 90048-90049)** — Posted sales invoices. Append-only.

**`purchaseInvoiceHeaders` / `purchaseInvoiceLines` (pages 90043-90044)** — Posted purchase invoices. Append-only.

**`salesHeaders` / `salesLines` (pages 90046-90047)** — Open (unposted) sales documents. These are CDC tables — records are modified and eventually deleted when posted.

**`purchaseHeaders` / `purchaseLines` (pages 90050, 90036)** — Open (unposted) purchase documents. CDC tables.

**`dimensionSetEntries` (page 90051)** — Links dimension combinations to transactions via `dimensionSetID`. Very high-volume. Note: this page does **not** have `ODataKeyFields = SystemId` set.

#### 51. `dimensionSetEntries`

| API Field Name | Source Field |
|---------------|-------------|
| `systemId` | SystemId |
| `dimensionCode` | Dimension Code |
| `dimensionName` | Dimension Name |
| `dimensionSetID` | Dimension Set ID |
| `dimensionValueCode` | Dimension Value Code |
| `dimensionValueID` | Dimension Value ID |
| `dimensionValueName` | Dimension Value Name |
| `globalDimensionNo` | Global Dimension No. |
| `systemCreatedAt` | SystemCreatedAt |
| `systemCreatedBy` | SystemCreatedBy |
| `systemModifiedAt` | SystemModifiedAt |
| `systemModifiedBy` | SystemModifiedBy |

---

## Get Object Primary Keys

All entities in the `standardEndpoints` group use **`systemId`** (Edm.Guid) as the OData key (`ODataKeyFields = SystemId`). This is the unique identifier for each record.

The metadata entities (`pageMetadata`, `tableMetadata`) and `dimensionSetEntries` do not explicitly define `ODataKeyFields`, so they use the underlying table's primary key(s) which are managed by Business Central internally.

| Entity Set | Primary Key |
|------------|-------------|
| All `standardEndpoints` entities | `systemId` |
| `pageMetadata` | `id` (page ID) |
| `tableMetadata` | `id` (table ID) |
| `dimensionSetEntries` | `systemId` (available as field, but composite key via `dimensionSetID` + `dimensionCode` in the underlying table) |

---

## Object's Ingestion Type

Since all custom API pages expose `systemModifiedAt`, most tables support CDC (incremental ingestion via the `systemModifiedAt` cursor). Posted/historical entities that are never modified after creation are effectively append-only.

| Entity Set | Ingestion Type | Rationale |
|------------|---------------|-----------|
| `pageMetadata` | `snapshot` | Metadata tables — small, rarely changes. Best as full refresh. |
| `tableMetadata` | `snapshot` | Metadata tables — small, rarely changes. Best as full refresh. |
| `generalLedgerAccounts` | `cdc_with_deletes` | Master data — records can be modified and deleted |
| `bankAccounts` | `cdc_with_deletes` | Master data — records can be modified and deleted |
| `companyInformation` | `cdc` | Single-row table — always updated in place, not deletable |
| `contacts` | `cdc_with_deletes` | Master data — records can be modified and deleted |
| `countriesRegions` | `cdc_with_deletes` | Setup data — can be modified and deleted |
| `currencies` | `cdc_with_deletes` | Setup data — can be modified and deleted |
| `currencyExchangeRates` | `cdc_with_deletes` | Rates can be added, adjusted, and deleted |
| `customers` | `cdc_with_deletes` | Master data — records are modified and can be deleted |
| `generalJournalBatches` | `cdc_with_deletes` | Batches can be modified and deleted |
| `reasonCodes` | `cdc_with_deletes` | Setup data — can be deleted |
| `generalJournalLines` | `cdc_with_deletes` | Open journal lines — modified and deleted when posted |
| `defaultDimensions` | `cdc_with_deletes` | Dimension assignments can change and be removed |
| `dimensionValues` | `cdc_with_deletes` | Setup data — can be deleted |
| `dimensions` | `cdc_with_deletes` | Setup data — can be deleted |
| `employees` | `cdc_with_deletes` | Master data — can be deleted |
| `generalLedgerEntries` | `append` | Posted entries are immutable. New entries only. |
| `generalProductPostingGroups` | `cdc_with_deletes` | Setup data — can be deleted |
| `vendors` | `cdc_with_deletes` | Master data — records are modified and can be deleted |
| `inventoryPostingGroups` | `cdc_with_deletes` | Setup data — can be deleted |
| `itemCategories` | `cdc_with_deletes` | Setup data — can be deleted |
| `itemLedgerEntries` | `append` | Posted entries are immutable. New entries only. |
| `itemVariants` | `cdc_with_deletes` | Master data — can be deleted |
| `items` | `cdc_with_deletes` | Master data — records are modified and can be deleted |
| `locations` | `cdc_with_deletes` | Master data — can be deleted |
| `opportunities` | `cdc_with_deletes` | CRM data — records are modified and can be deleted |
| `paymentMethods` | `cdc_with_deletes` | Setup data — can be deleted |
| `paymentTerms` | `cdc_with_deletes` | Setup data — can be deleted |
| `purchaseReceiptLines` | `append` | Posted — immutable after posting |
| `salesCreditMemoLines` | `append` | Posted — immutable after posting |
| `purchaseReceiptHeaders` | `append` | Posted — immutable after posting |
| `jobs` | `cdc_with_deletes` | Project data — records are modified and can be deleted |
| `rawCompanies` | `snapshot` | Small table, rarely changes |
| `salesCreditMemoHeaders` | `append` | Posted — immutable after posting |
| `purchaseLines` | `cdc_with_deletes` | Open documents — modified and deleted when posted |
| `salesShipmentLines` | `append` | Posted — immutable after posting |
| `salesShipmentHeaders` | `append` | Posted — immutable after posting |
| `shipmentMethods` | `cdc_with_deletes` | Setup data — can be deleted |
| `unitsOfMeasure` | `cdc_with_deletes` | Setup data — can be deleted |
| `postedGeneralJournalBatch` | `append` | Posted — immutable |
| `postedGeneralJournalLines` | `append` | Posted — immutable |
| `purchaseInvoiceHeaders` | `append` | Posted — immutable after posting |
| `purchaseInvoiceLines` | `append` | Posted — immutable after posting |
| `timeSheetDetails` | `cdc_with_deletes` | Time entries can be modified and deleted |
| `salesHeaders` | `cdc_with_deletes` | Open documents — modified and deleted when posted |
| `salesLines` | `cdc_with_deletes` | Open documents — modified and deleted when posted |
| `salesInvoiceHeaders` | `append` | Posted — immutable after posting |
| `salesInvoiceLines` | `append` | Posted — immutable after posting |
| `purchaseHeaders` | `cdc_with_deletes` | Open documents — modified and deleted when posted |
| `dimensionSetEntries` | `snapshot` | Very high-volume, no reliable incremental cursor. Best as snapshot. |

**Delete tracking** is enabled via a custom AL extension (`initialSetup_databricks.al`) that deploys a global `OnDatabaseDelete` event handler. See the **Delete Tracking** section below for details.

---

## Read API for Data Retrieval

### HTTP Method

All reads use **GET** requests to the OData v4 endpoints.

### Endpoint Pattern

**Company-scoped (standardEndpoints):**
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/{entitySetName}
```

**Non-company-scoped (metadata):**
```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/metadata/v1.0/{entitySetName}
```

### Pagination

Business Central OData APIs use **server-driven pagination**:

- The server returns a page of records (default page size varies, typically 2000 for custom APIs).
- If more records exist, the response includes an `@odata.nextLink` URL.
- The client follows `@odata.nextLink` until it is absent, indicating the last page.

**Example paginated response:**
```json
{
  "@odata.context": "...",
  "value": [ ... ],
  "@odata.nextLink": "https://api.businesscentral.dynamics.com/v2.0/.../customers?$skip=2000"
}
```

There is no client-controllable `$top` or `$limit` for page size on custom API pages — the server controls the page size.

### Incremental Data Retrieval (Filtering)

Use the OData `$filter` query parameter with `systemModifiedAt` for incremental reads:

```
GET .../customers?$filter=systemModifiedAt gt {last_sync_timestamp}
```

**For append-only tables** (posted entries), filter on `systemCreatedAt` instead:

```
GET .../generalLedgerEntries?$filter=systemCreatedAt gt {last_sync_timestamp}
```

**Ordering for deterministic cursors:**
```
GET .../customers?$filter=systemModifiedAt gt {last_sync_timestamp}&$orderby=systemModifiedAt asc
```

**TBD:** Verify whether `$orderby` is supported on all custom API pages. Standard BC APIs sometimes restrict ordering. If not supported, client-side sorting on `systemModifiedAt` will be needed.

### Example: Full Read

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/customers
Authorization: Bearer {access_token}
```

### Example: Incremental Read

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/standardEndpoints/v1.0/companies({company_id})/customers?$filter=systemModifiedAt gt 2025-01-15T10:30:00Z&$orderby=systemModifiedAt asc
Authorization: Bearer {access_token}
```

### Multi-Company Support

The connector must support reading from multiple companies. The `rawCompanies` endpoint returns the list of companies:

```
GET .../api/databricks/standardEndpoints/v1.0/companies
```

This returns:
```json
{
  "value": [
    { "id": "guid-1", "name": "CRONUS USA, Inc.", "displayName": "CRONUS USA, Inc." },
    { "id": "guid-2", "name": "My Company", "displayName": "My Company" }
  ]
}
```

The connector should accept a `company_id` connection parameter. Optionally, it could iterate over all companies.

### Rate Limits

Business Central enforces the following API rate limits:

| Limit | Value |
|-------|-------|
| Requests per minute (per environment) | 6,000 |
| Concurrent requests | 5 |
| Request timeout | 600 seconds |
| Max response payload size | ~20 MB |

The connector should implement retry logic with exponential backoff for HTTP 429 (Too Many Requests) responses. The `Retry-After` header indicates how long to wait.

### Handling Large Datasets

For high-volume tables like `generalLedgerEntries` or `itemLedgerEntries`:
- Always use `$filter` to scope the query to a time window.
- Use a sliding time-window approach to avoid unbounded queries.
- Combine with `max_records_per_batch` admission control.

---

## Delete Tracking

Delete tracking is implemented via a custom AL extension (`initialSetup_databricks.al`) that captures delete events and writes them to a log table that the connector can poll.

### Architecture

The delete tracking system consists of three components:

1. **`Delete Tracker` table (90101)** — Stores which tables should be tracked for deletes. The connector registers a tracker for each table it wants to monitor.
2. **`Databricks Deleted Record` table (90100)** — A log of all deleted records. Each entry records the `systemId` of the deleted record, the `tableId`, `companyId`, and `deletedAt` timestamp.
3. **`DatabricksDeleteEventHandler` codeunit (90100)** — Subscribes to the global `OnDatabaseDelete` trigger. When a record is deleted from a subscribed table, it writes the deleted record's metadata to the `Databricks Deleted Record` log table.

### Setup: Register Delete Trackers

Before delete tracking works for a given table, the connector must register a tracker via the `deleteTrackers` API:

```
POST https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/deleteTracking/v1.0/deleteTrackers
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "tableId": 18,
  "companyId": "{company_id_guid}"
}
```

Where `tableId` is the BC internal table ID (e.g., `18` = Customer, `27` = Item). Use `'ALL'` as `companyId` for shared (non-per-company) tables.

The `tableMetadata` endpoint can be used to look up table IDs by name. The `tableId` for each entity's source table can also be mapped at connector initialization time. Use `'ALL'` as `companyId` for shared (non-per-company) tables.

### Reading Deleted Records

The connector polls the `deletedRecords` endpoint to discover which records were deleted:

```
GET https://api.businesscentral.dynamics.com/v2.0/{tenant_id}/{environment}/api/databricks/deleteTracking/v1.0/deletedRecords?$filter=tableId eq {table_id} and companyId eq '{company_id}' and deletedAt gt {last_sync_timestamp}&$orderby=deletedAt asc
Authorization: Bearer {access_token}
```

**Response:**
```json
{
  "value": [
    {
      "entryNo": 1,
      "tableId": 18,
      "companyId": "a1b2c3d4-...",
      "deletedSystemId": "f5e6d7c8-...",
      "recordPosition": "No.='10000'",
      "deletedAt": "2025-03-05T14:30:00Z",
      "systemModifiedAtOriginal": "2025-03-05T14:29:55Z",
      "systemId": "...",
      "systemCreatedAt": "2025-03-05T14:30:00Z",
      "systemModifiedAt": "2025-03-05T14:30:00Z"
    }
  ]
}
```

### Implementing `read_table_deletes`

For tables with `cdc_with_deletes` ingestion type, the connector's `read_table_deletes()` method should:

1. Query the `deletedRecords` endpoint filtered by `tableId` and `companyId`
2. Filter by `deletedAt gt {last_cursor}` for incremental delete sync
3. Return records containing at minimum the primary key (`systemId` from the `deletedSystemId` field) and cursor field (`deletedAt`)

The `deletedSystemId` field in the response corresponds to the `systemId` of the original record that was deleted — this is the primary key used for delete propagation.

### Table ID Mapping

The connector needs to map entity set names to BC table IDs for subscription registration. This mapping can be derived from the `tableMetadata` and `pageMetadata` endpoints, or hardcoded based on the AL source. Key mappings:

| Entity Set Name | Source Table | BC Table ID |
|-----------------|-------------|-------------|
| `generalLedgerAccounts` | G/L Account | 15 |
| `bankAccounts` | Bank Account | 270 |
| `contacts` | Contact | 5050 |
| `customers` | Customer | 18 |
| `vendors` | Vendor | 23 |
| `items` | Item | 27 |
| `employees` | Employee | 5200 |
| `generalJournalLines` | Gen. Journal Line | 81 |
| `salesHeaders` | Sales Header | 36 |
| `salesLines` | Sales Line | 37 |
| `purchaseHeaders` | Purchase Header | 38 |
| `purchaseLines` | Purchase Line | 39 |
| `jobs` | Job | 167 |
| `opportunities` | Opportunity | 5092 |

TBD: Complete table ID mapping can be retrieved dynamically via the `tableMetadata` endpoint by matching on table `name`.

### Log Table Maintenance

The `Databricks Deleted Record` log table will grow over time. The connector or a scheduled BC job should periodically purge old entries (e.g., entries older than 30 days) to prevent unbounded growth. This is an operational concern to document for end users.

---

## Field Type Mapping

Business Central OData field types map to Python/Spark types as follows:

| OData Type (Edm.) | BC Field Type | Python Type | Spark Type | Notes |
|--------------------|---------------|-------------|------------|-------|
| `Edm.String` | Code, Text | `str` | `StringType` | |
| `Edm.Int32` | Integer | `int` | `IntegerType` | Prefer `LongType` to avoid overflow |
| `Edm.Int64` | BigInteger | `int` | `LongType` | |
| `Edm.Decimal` | Decimal | `float` | `DecimalType` | |
| `Edm.Boolean` | Boolean | `bool` | `BooleanType` | |
| `Edm.Date` | Date | `str` | `StringType` | Format: `YYYY-MM-DD` |
| `Edm.DateTimeOffset` | DateTime | `str` | `StringType` | ISO 8601 with timezone |
| `Edm.Guid` | GUID | `str` | `StringType` | Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `Edm.Stream` | Media, Blob | `str` | `StringType` | Base64-encoded or URL reference |
| Enum types | Option, Enum | `str` | `StringType` | String representation of the enum value |
| `Edm.Duration` | DateFormula | `str` | `StringType` | ISO 8601 duration format |

### Special Field Behaviors

- **FlowFields** (computed fields like `balance`, `netChange`): Calculated server-side. Read-only. The AL page includes these as regular fields, and they are returned in the OData response as computed values.
- **FlowFilters** (fields like `dateFilter`, `budgetFilter`, `locationFilter`): These appear as fields in the schema but are used for filtering FlowField calculations. They will typically return empty/null in the API response. They should still be included in the schema.
- **Enum/Option fields** (like `accountType`, `status`, `blocked`): Returned as their string representation (e.g., `"Posting"`, `"Open"`, `"All"`).
- **GUID fields** (`systemId`, `systemCreatedBy`, `systemModifiedBy`): Returned as string GUIDs.

---

## Sources and References

| Source Type | URL | Confidence | What it confirmed |
|-------------|-----|------------|-------------------|
| User-provided AL source code | `initial_setup_periodic_reimport.al` (local file) | Highest | Complete API page definitions, all field schemas, entity names, API groups, OData key fields |
| User-provided AL source code | `initialSetup.al` (local file) | Highest | Delete tracking mechanism (webhook-based, Fivetran pattern) — adapted for pull-based in `initialSetup_databricks.al` |
| User-provided AL source code | `initialSetup_databricks.al` (local file) | Highest | Pull-based delete tracking: Databricks Deleted Record log table, Delete Tracker table, DatabricksDeleteEventHandler codeunit |
| Microsoft Official Docs — Custom API Pages | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api | High | API page structure, OData URL patterns, authentication |
| Microsoft Official Docs — API Rate Limits | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/operational-limits-online | High | Rate limits, concurrent connections, timeouts |
| Microsoft Official Docs — OData Filtering | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-connect-apps-filtering | High | `$filter`, `$orderby`, `$top` support |
| Microsoft Official Docs — OAuth 2.0 | https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-connect-apps | High | Client credentials flow, token endpoint, scopes |
