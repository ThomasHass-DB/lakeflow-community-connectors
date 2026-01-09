-- =============================================================================
-- HubSpot Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('hubspot', 'HubSpot', 'HubSpot CRM connector for contacts, companies, deals, tickets, and engagement objects.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('hubspot', 'contacts', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/contacts', 350, 50),
('hubspot', 'companies', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/companies', 650, 50),
('hubspot', 'deals', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/deals', 500, 200),
('hubspot', 'tickets', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/tickets', 800, 200),
('hubspot', 'calls', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/calls', 50, 350),
('hubspot', 'emails', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/email', 250, 350),
('hubspot', 'meetings', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/meetings', 450, 350),
('hubspot', 'tasks', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/tasks', 650, 350),
('hubspot', 'notes', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/notes', 850, 350),
('hubspot', 'deal_split', 'incremental', 'updatedAt', 'https://developers.hubspot.com/docs/api/crm/deals', 500, 350);

-- 3. Contacts columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_email', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_firstname', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties_lastname', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('properties_phone', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('associations_companies', 'ARRAY<STRING>', 8, FALSE, FALSE, NULL, NULL),
    ('associations_deals', 'ARRAY<STRING>', 9, FALSE, FALSE, NULL, NULL),
    ('associations_tickets', 'ARRAY<STRING>', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'contacts';

-- 4. Companies columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_name', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_domain', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties_industry', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 7, FALSE, FALSE, NULL, NULL),
    ('associations_deals', 'ARRAY<STRING>', 8, FALSE, FALSE, NULL, NULL),
    ('associations_tickets', 'ARRAY<STRING>', 9, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'companies';

-- 5. Deals columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_dealname', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_amount', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties_dealstage', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('properties_pipeline', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 8, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 9, FALSE, TRUE, 'companies', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 10, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'deals';

-- 6. Tickets columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_subject', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_content', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties_priority', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('properties_status', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 8, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 9, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 10, FALSE, TRUE, 'deals', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'tickets';

-- 7. Calls columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_hs_call_duration', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_hs_call_outcome', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 6, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 7, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 8, FALSE, TRUE, 'deals', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 9, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'calls';

-- 8. Emails columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_hs_email_subject', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_hs_email_body', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 6, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 7, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 8, FALSE, TRUE, 'deals', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 9, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'emails';

-- 9. Meetings columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_hs_meeting_title', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_hs_meeting_start_time', 'TIMESTAMP', 5, FALSE, FALSE, NULL, NULL),
    ('properties_hs_meeting_end_time', 'TIMESTAMP', 6, FALSE, FALSE, NULL, NULL),
    ('properties_hs_meeting_location', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 8, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 9, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 10, FALSE, TRUE, 'deals', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 11, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'meetings';

-- 10. Tasks columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_hs_task_subject', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_hs_task_status', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('properties_hs_task_priority', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('properties_hs_timestamp', 'TIMESTAMP', 7, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 8, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 9, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 10, FALSE, TRUE, 'deals', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 11, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'tasks';

-- 11. Notes columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('properties_hs_note_body', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('properties_hs_timestamp', 'TIMESTAMP', 5, FALSE, FALSE, NULL, NULL),
    ('associations_contacts', 'ARRAY<STRING>', 6, FALSE, TRUE, 'contacts', 'id'),
    ('associations_companies', 'ARRAY<STRING>', 7, FALSE, TRUE, 'companies', 'id'),
    ('associations_deals', 'ARRAY<STRING>', 8, FALSE, TRUE, 'deals', 'id'),
    ('associations_tickets', 'ARRAY<STRING>', 9, FALSE, TRUE, 'tickets', 'id')
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'notes';

-- 12. Deal Split columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('createdAt', 'TIMESTAMP', 1, FALSE, FALSE, NULL, NULL),
    ('updatedAt', 'TIMESTAMP', 2, FALSE, FALSE, NULL, NULL),
    ('archived', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'hubspot' AND t.name = 'deal_split';

