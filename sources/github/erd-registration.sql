-- =============================================================================
-- GitHub Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('github', 'GitHub', 'GitHub REST API v3 connector for issues, repositories, pull requests, commits, and more.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('github', 'repositories', 'snapshot', NULL, 'https://docs.github.com/en/rest/repos/repos', 500, 50),
('github', 'issues', 'incremental', 'updated_at', 'https://docs.github.com/en/rest/issues/issues', 200, 200),
('github', 'pull_requests', 'incremental', 'updated_at', 'https://docs.github.com/en/rest/pulls/pulls', 500, 200),
('github', 'comments', 'incremental', 'updated_at', 'https://docs.github.com/en/rest/issues/comments', 50, 400),
('github', 'commits', 'incremental', NULL, 'https://docs.github.com/en/rest/commits/commits', 350, 400),
('github', 'reviews', 'incremental', NULL, 'https://docs.github.com/en/rest/pulls/reviews', 650, 400),
('github', 'assignees', 'snapshot', NULL, 'https://docs.github.com/en/rest/issues/assignees', 800, 200),
('github', 'branches', 'snapshot', NULL, 'https://docs.github.com/en/rest/branches/branches', 950, 200),
('github', 'collaborators', 'snapshot', NULL, 'https://docs.github.com/en/rest/collaborators/collaborators', 950, 50),
('github', 'organizations', 'snapshot', NULL, 'https://docs.github.com/en/rest/orgs/orgs', 50, 50),
('github', 'teams', 'snapshot', NULL, 'https://docs.github.com/en/rest/teams/teams', 200, 50),
('github', 'users', 'snapshot', NULL, 'https://docs.github.com/en/rest/users/users', 800, 50);

-- 3. Repositories columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('full_name', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('repository_name', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('private', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('fork', 'BOOLEAN', 7, FALSE, FALSE, NULL, NULL),
    ('created_at', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('pushed_at', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('stargazers_count', 'BIGINT', 11, FALSE, FALSE, NULL, NULL),
    ('watchers_count', 'BIGINT', 12, FALSE, FALSE, NULL, NULL),
    ('forks_count', 'BIGINT', 13, FALSE, FALSE, NULL, NULL),
    ('owner', 'STRUCT', 14, FALSE, FALSE, NULL, NULL),
    ('permissions', 'STRUCT', 15, FALSE, FALSE, NULL, NULL),
    ('license', 'STRUCT', 16, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'repositories';

-- 4. Issues columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('number', 'BIGINT', 1, FALSE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 2, FALSE, TRUE, 'repositories', 'repository_owner'),
    ('repository_name', 'STRING', 3, FALSE, TRUE, 'repositories', 'repository_name'),
    ('title', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('state', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('created_at', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('closed_at', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('user', 'STRUCT', 10, FALSE, FALSE, NULL, NULL),
    ('assignee', 'STRUCT', 11, FALSE, FALSE, NULL, NULL),
    ('assignees', 'ARRAY<STRUCT>', 12, FALSE, FALSE, NULL, NULL),
    ('labels', 'ARRAY<STRUCT>', 13, FALSE, FALSE, NULL, NULL),
    ('milestone', 'STRUCT', 14, FALSE, FALSE, NULL, NULL),
    ('pull_request', 'STRUCT', 15, FALSE, FALSE, NULL, NULL),
    ('reactions', 'STRUCT', 16, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'issues';

-- 5. Pull Requests columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('number', 'BIGINT', 1, FALSE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 2, FALSE, TRUE, 'repositories', 'repository_owner'),
    ('repository_name', 'STRING', 3, FALSE, TRUE, 'repositories', 'repository_name'),
    ('title', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('state', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('created_at', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('closed_at', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('merged_at', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('user', 'STRUCT', 11, FALSE, FALSE, NULL, NULL),
    ('head', 'STRUCT', 12, FALSE, FALSE, NULL, NULL),
    ('base', 'STRUCT', 13, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'pull_requests';

-- 6. Comments columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 1, FALSE, TRUE, 'repositories', 'repository_owner'),
    ('repository_name', 'STRING', 2, FALSE, TRUE, 'repositories', 'repository_name'),
    ('issue_url', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('created_at', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('user', 'STRUCT', 7, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'comments';

-- 7. Commits columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('sha', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 1, FALSE, TRUE, 'repositories', 'repository_owner'),
    ('repository_name', 'STRING', 2, FALSE, TRUE, 'repositories', 'repository_name'),
    ('message', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('author', 'STRUCT', 4, FALSE, FALSE, NULL, NULL),
    ('committer', 'STRUCT', 5, FALSE, FALSE, NULL, NULL),
    ('tree', 'STRUCT', 6, FALSE, FALSE, NULL, NULL),
    ('parents', 'ARRAY<STRUCT>', 7, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'commits';

-- 8. Reviews columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('repository_owner', 'STRING', 1, FALSE, TRUE, 'repositories', 'repository_owner'),
    ('repository_name', 'STRING', 2, FALSE, TRUE, 'repositories', 'repository_name'),
    ('pull_request_number', 'BIGINT', 3, FALSE, TRUE, 'pull_requests', 'number'),
    ('user', 'STRUCT', 4, FALSE, FALSE, NULL, NULL),
    ('body', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('state', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('submitted_at', 'STRING', 7, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'reviews';

-- 9. Assignees columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('repository_owner', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('repository_name', 'STRING', 1, TRUE, FALSE, NULL, NULL),
    ('id', 'BIGINT', 2, TRUE, FALSE, NULL, NULL),
    ('login', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('avatar_url', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 5, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'assignees';

-- 10. Branches columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('repository_owner', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('repository_name', 'STRING', 1, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 2, TRUE, FALSE, NULL, NULL),
    ('commit', 'STRUCT', 3, FALSE, FALSE, NULL, NULL),
    ('protected', 'BOOLEAN', 4, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'branches';

-- 11. Collaborators columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('repository_owner', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('repository_name', 'STRING', 1, TRUE, FALSE, NULL, NULL),
    ('id', 'BIGINT', 2, TRUE, FALSE, NULL, NULL),
    ('login', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('avatar_url', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('permissions', 'STRUCT', 6, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'collaborators';

-- 12. Organizations columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('login', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('avatar_url', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('url', 'STRING', 4, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'organizations';

-- 13. Teams columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('name', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('slug', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('permission', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('privacy', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('organization', 'STRUCT', 6, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'teams';

-- 14. Users columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'BIGINT', 0, TRUE, FALSE, NULL, NULL),
    ('login', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('email', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('avatar_url', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('bio', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('company', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('location', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('created_at', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'STRING', 9, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'github' AND t.name = 'users';

