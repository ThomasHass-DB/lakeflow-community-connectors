# Lakeflow Connect ERD Integration Prompt

> Use this prompt when generating INSERT statements for the Interactive ERD Visualization App

---

## Instructions

When a new Lakeflow Connect community connector is defined, generate SQL INSERT statements to register it in the ERD visualization application. The ERD app displays interactive entity-relationship diagrams for connector schemas.

**Source:** Read the connector definition from `sources/{{source_name}}/README.md` to extract table structures, columns, relationships, and ingestion modes.

**Output:** Create a new file `sources/{{source_name}}/erd-registration.sql` containing the INSERT statements.

## Database Schema

The ERD app uses three tables in Lakebase:

### 1. `connectors` - Connector metadata

```sql
CREATE TABLE connectors (
    id VARCHAR(100) PRIMARY KEY,        -- Unique connector ID (e.g., 'youtube', 'salesforce')
    name VARCHAR(255) NOT NULL,         -- Display name (e.g., 'YouTube', 'Salesforce')
    description TEXT,                   -- Brief description of the connector
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### 2. `connector_tables` - Tables within a connector

```sql
CREATE TABLE connector_tables (
    id SERIAL PRIMARY KEY,
    connector_id VARCHAR(100) NOT NULL,  -- References connectors.id
    name VARCHAR(255) NOT NULL,          -- Table name (e.g., 'video', 'account')
    ingestion_mode VARCHAR(20) NOT NULL, -- 'snapshot' or 'incremental'
    cursor_column VARCHAR(255),          -- Column used for incremental ingestion (NULL for snapshot)
    docs_url TEXT,                       -- Link to API documentation
    position_x INTEGER DEFAULT 0,        -- X position in ERD canvas (for layout)
    position_y INTEGER DEFAULT 0,        -- Y position in ERD canvas (for layout)
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### 3. `table_columns` - Columns within tables

```sql
CREATE TABLE table_columns (
    id SERIAL PRIMARY KEY,
    table_id INTEGER NOT NULL,           -- References connector_tables.id
    name VARCHAR(255) NOT NULL,          -- Column name
    data_type VARCHAR(100),              -- Data type (STRING, INT, TIMESTAMP, STRUCT, etc.)
    ordinal_position INTEGER DEFAULT 0,  -- Column order (0-indexed)
    is_primary_key BOOLEAN DEFAULT FALSE,
    is_foreign_key BOOLEAN DEFAULT FALSE,
    references_table VARCHAR(255),       -- If FK: referenced table name
    references_column VARCHAR(255),      -- If FK: referenced column name
);
```

## Required Information from Connector Definition

Extract the following from `sources/{{source_name}}/README.md`:

1. **Connector ID** - Lowercase identifier matching the source folder name (e.g., `youtube`, `hubspot`, `stripe`)
2. **Connector Name** - Display name
3. **Description** - What the connector does
4. **For each table:**
   - Table name
   - Ingestion mode (`snapshot` or `incremental`)
   - Cursor column (for incremental tables)
   - API documentation URL
   - Initial position (x, y) for ERD layout
5. **For each column:**
   - Column name
   - Data type
   - Whether it's a primary key
   - Whether it's a foreign key (and what it references)

## Output Format

Generate SQL INSERT statements in this order:

```sql
-- =============================================================================
-- {CONNECTOR_NAME} Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('{connector_id}', '{Connector Name}', '{Description}');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('{connector_id}', '{table1}', '{mode}', '{cursor_col}', '{docs_url}', {x}, {y}),
('{connector_id}', '{table2}', '{mode}', NULL, '{docs_url}', {x}, {y});

-- 3. Insert columns for each table
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('{col_name}', '{DATA_TYPE}', 0, {is_pk}, {is_fk}, {ref_table}, {ref_col}),
    ('{col_name}', '{DATA_TYPE}', 1, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = '{connector_id}' AND t.name = '{table_name}';
```

## Layout Guidelines

For `position_x` and `position_y`, arrange tables logically:
- **Central/main tables** (e.g., the primary entity): center of canvas (~350-650, 50-200)
- **Related tables**: positioned relative to what they reference
- **Spacing**: ~300px horizontal, ~200px vertical between tables
- **Group by relationship**: Tables with FK relationships should be near their referenced tables

Example layout pattern:
```
(50, 50)    (350, 50)    (650, 50)    (900, 50)
   ↓            ↓            ↓            ↓
caption      video       playlist     channel
                            
(50, 250)   (50, 450)
   ↓            ↓
retention   comment
```

## Example Output

For a hypothetical "Stripe" connector (based on `sources/stripe/README.md`):

```sql
-- =============================================================================
-- Stripe Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('stripe', 'Stripe', 'Stripe payments platform connector for customers, charges, and subscriptions.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('stripe', 'customer', 'incremental', 'created', 'https://stripe.com/docs/api/customers', 500, 50),
('stripe', 'charge', 'incremental', 'created', 'https://stripe.com/docs/api/charges', 200, 250),
('stripe', 'subscription', 'incremental', 'created', 'https://stripe.com/docs/api/subscriptions', 800, 250);

-- 3. Customer columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('email', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('created', 'TIMESTAMP', 3, FALSE, FALSE, NULL, NULL),
    ('metadata', 'MAP', 4, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'customer';

-- 4. Charge columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('customer_id', 'STRING', 1, FALSE, TRUE, 'customer', 'id'),
    ('amount', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('created', 'TIMESTAMP', 5, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'charge';

-- 5. Subscription columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('customer_id', 'STRING', 1, FALSE, TRUE, 'customer', 'id'),
    ('status', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('current_period_start', 'TIMESTAMP', 3, FALSE, FALSE, NULL, NULL),
    ('current_period_end', 'TIMESTAMP', 4, FALSE, FALSE, NULL, NULL),
    ('created', 'TIMESTAMP', 5, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'subscription';
```

## Data Type Mapping

Use these data types consistently:

| Source Type | ERD Data Type |
|-------------|---------------|
| String, Text, VARCHAR | `STRING` |
| Integer, Int32 | `INT` |
| Long, Int64, BigInt | `BIGINT` |
| Float, Double | `DOUBLE` |
| Boolean | `BOOLEAN` |
| Date | `DATE` |
| DateTime, Timestamp | `TIMESTAMP` |
| JSON, Object | `STRUCT` |
| Array | `ARRAY<{element_type}>` |
| Map, Dict | `MAP` |

---

**ERD App Repository:** Lakeflow Connect Community Connectors ERD
