-- =============================================================================
-- Mixpanel Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('mixpanel', 'Mixpanel', 'Mixpanel analytics connector for events, cohorts, cohort members, and user profiles.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('mixpanel', 'events', 'incremental', 'properties.time', 'https://developer.mixpanel.com/reference/raw-event-export', 350, 50),
('mixpanel', 'cohorts', 'snapshot', NULL, 'https://developer.mixpanel.com/reference/cohorts', 650, 50),
('mixpanel', 'cohort_members', 'snapshot', NULL, 'https://developer.mixpanel.com/reference/cohorts', 650, 200),
('mixpanel', 'engage', 'incremental', '$properties.$last_seen', 'https://developer.mixpanel.com/reference/engage', 350, 200);

-- 3. Events columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('$insert_id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('event', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('properties.distinct_id', 'STRING', 2, FALSE, TRUE, 'engage', '$distinct_id'),
    ('properties.time', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('properties.$browser', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties.$city', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties.$os', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('properties.$device', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('properties.$region', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('properties.$country_code', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('properties.custom_properties', 'MAP', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'mixpanel' AND t.name = 'events';

-- 4. Cohorts columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('count', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('is_visible', 'BOOLEAN', 4, FALSE, FALSE, NULL, NULL),
    ('is_dynamic', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('created', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('project_id', 'BIGINT', 7, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'mixpanel' AND t.name = 'cohorts';

-- 5. Cohort Members columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('cohort_id', 'BIGINT', 0, TRUE, TRUE, 'cohorts', 'id'),
    ('distinct_id', 'STRING', 1, TRUE, TRUE, 'engage', '$distinct_id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'mixpanel' AND t.name = 'cohort_members';

-- 6. Engage (User Profiles) columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('$distinct_id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('$properties.$first_name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('$properties.$last_name', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('$properties.$email', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('$properties.$phone', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('$properties.$city', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('$properties.$region', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('$properties.$country_code', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('$properties.$last_seen', 'BIGINT', 8, FALSE, FALSE, NULL, NULL),
    ('$properties.$created', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('$properties.custom_properties', 'MAP', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'mixpanel' AND t.name = 'engage';

