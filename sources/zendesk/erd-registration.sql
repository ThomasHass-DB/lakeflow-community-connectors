-- =============================================================================
-- Zendesk Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('zendesk', 'Zendesk', 'Zendesk support platform connector for tickets, users, organizations, and help center articles.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('zendesk', 'tickets', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/', 350, 50),
('zendesk', 'organizations', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/organizations/organizations/', 650, 50),
('zendesk', 'users', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/users/users/', 500, 200),
('zendesk', 'ticket_comments', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_comments/', 200, 200),
('zendesk', 'articles', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/help_center/help-center-api/articles/', 800, 200),
('zendesk', 'groups', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/groups/groups/', 350, 350),
('zendesk', 'brands', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/ticketing/account-configuration/brands/', 650, 350),
('zendesk', 'topics', 'incremental', 'updated_at', 'https://developer.zendesk.com/api-reference/help_center/help-center-api/topics/', 800, 350);

-- 3. Tickets columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('subject', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('priority', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('requester_id', 'BIGINT', 5, FALSE, TRUE, 'users', 'id'),
    ('assignee_id', 'BIGINT', 6, FALSE, TRUE, 'users', 'id'),
    ('organization_id', 'BIGINT', 7, FALSE, TRUE, 'organizations', 'id'),
    ('group_id', 'BIGINT', 8, FALSE, TRUE, 'groups', 'id'),
    ('brand_id', 'BIGINT', 9, FALSE, TRUE, 'brands', 'id'),
    ('tags', 'ARRAY<STRING>', 10, FALSE, FALSE, NULL, NULL),
    ('custom_fields', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 12, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 13, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'tickets';

-- 4. Organizations columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('domain_names', 'ARRAY<STRING>', 2, FALSE, FALSE, NULL, NULL),
    ('group_id', 'BIGINT', 3, FALSE, TRUE, 'groups', 'id'),
    ('details', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('notes', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('tags', 'ARRAY<STRING>', 6, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 7, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 8, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'organizations';

-- 5. Users columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('email', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('role', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('organization_id', 'BIGINT', 4, FALSE, TRUE, 'organizations', 'id'),
    ('active', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('phone', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('time_zone', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('tags', 'ARRAY<STRING>', 8, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 9, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'users';

-- 6. Ticket Comments columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('ticket_id', 'BIGINT', 1, FALSE, TRUE, 'tickets', 'id'),
    ('type', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('author_id', 'BIGINT', 4, FALSE, TRUE, 'users', 'id'),
    ('public', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('attachments', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 7, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 8, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'ticket_comments';

-- 7. Articles columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('title', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('section_id', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('author_id', 'BIGINT', 4, FALSE, TRUE, 'users', 'id'),
    ('draft', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('promoted', 'BOOLEAN', 6, FALSE, FALSE, NULL, NULL),
    ('locale', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('vote_sum', 'BIGINT', 8, FALSE, FALSE, NULL, NULL),
    ('vote_count', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 10, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 11, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'articles';

-- 8. Groups columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('default', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('deleted', 'BOOLEAN', 4, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 5, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 6, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'groups';

-- 9. Brands columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('brand_url', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('subdomain', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('active', 'BOOLEAN', 4, FALSE, FALSE, NULL, NULL),
    ('default', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('logo_url', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 7, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 8, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'brands';

-- 10. Topics columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('community_id', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('position', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('follower_count', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('created_at', 'TIMESTAMP', 6, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 7, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'zendesk' AND t.name = 'topics';

