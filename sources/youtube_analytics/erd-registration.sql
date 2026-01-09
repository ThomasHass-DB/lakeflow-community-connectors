-- =============================================================================
-- YouTube Analytics Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('youtube_analytics', 'YouTube Analytics', 'YouTube Data API v3 connector for captions, channels, comments, playlists, and videos.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('youtube_analytics', 'channels', 'snapshot', NULL, 'https://developers.google.com/youtube/v3/docs/channels', 500, 50),
('youtube_analytics', 'videos', 'snapshot', NULL, 'https://developers.google.com/youtube/v3/docs/videos', 350, 200),
('youtube_analytics', 'playlists', 'snapshot', NULL, 'https://developers.google.com/youtube/v3/docs/playlists', 650, 200),
('youtube_analytics', 'comments', 'incremental', 'updated_at', 'https://developers.google.com/youtube/v3/docs/comments', 200, 350),
('youtube_analytics', 'captions', 'snapshot', NULL, 'https://developers.google.com/youtube/v3/docs/captions', 500, 350);

-- 3. Channels columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('etag', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('kind', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('title', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('custom_url', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('published_at', 'TIMESTAMP', 6, FALSE, FALSE, NULL, NULL),
    ('country', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('thumbnail_url', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('default_language', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('localized_title', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('localized_description', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('total_view_count', 'BIGINT', 12, FALSE, FALSE, NULL, NULL),
    ('total_subscriber_count', 'BIGINT', 13, FALSE, FALSE, NULL, NULL),
    ('total_video_count', 'BIGINT', 14, FALSE, FALSE, NULL, NULL),
    ('hidden_subscriber_count', 'BOOLEAN', 15, FALSE, FALSE, NULL, NULL),
    ('uploads_playlist_id', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('likes_playlist_id', 'STRING', 17, FALSE, FALSE, NULL, NULL),
    ('keywords', 'STRING', 18, FALSE, FALSE, NULL, NULL),
    ('topic_categories', 'ARRAY<STRING>', 19, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 20, FALSE, FALSE, NULL, NULL),
    ('branding_settings', 'STRING', 21, FALSE, FALSE, NULL, NULL),
    ('localizations', 'STRING', 22, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'youtube_analytics' AND t.name = 'channels';

-- 4. Videos columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('etag', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('kind', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('published_at', 'TIMESTAMP', 3, FALSE, FALSE, NULL, NULL),
    ('channel_id', 'STRING', 4, FALSE, TRUE, 'channels', 'id'),
    ('title', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('channel_title', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('tags', 'ARRAY<STRING>', 8, FALSE, FALSE, NULL, NULL),
    ('category_id', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('thumbnail_url', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('content_details_duration', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('content_details_definition', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('statistics_view_count', 'BIGINT', 13, FALSE, FALSE, NULL, NULL),
    ('statistics_like_count', 'BIGINT', 14, FALSE, FALSE, NULL, NULL),
    ('statistics_comment_count', 'BIGINT', 15, FALSE, FALSE, NULL, NULL),
    ('status_privacy_status', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('status_made_for_kids', 'BOOLEAN', 17, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'youtube_analytics' AND t.name = 'videos';

-- 5. Playlists columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('channel_id', 'STRING', 1, FALSE, TRUE, 'channels', 'id'),
    ('title', 'STRING', 2, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 3, FALSE, FALSE, NULL, NULL),
    ('published_at', 'TIMESTAMP', 4, FALSE, FALSE, NULL, NULL),
    ('total_item_count', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('podcast_status', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('privacy_status', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('thumbnail_url', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('channel_title', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('default_language', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('player_embed_html', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('localized_title', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('localized_description', 'STRING', 13, FALSE, FALSE, NULL, NULL),
    ('localizations', 'STRING', 14, FALSE, FALSE, NULL, NULL),
    ('kind', 'STRING', 15, FALSE, FALSE, NULL, NULL),
    ('etag', 'STRING', 16, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'youtube_analytics' AND t.name = 'playlists';

-- 6. Comments columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('video_id', 'STRING', 1, FALSE, TRUE, 'videos', 'id'),
    ('can_reply', 'BOOLEAN', 2, FALSE, FALSE, NULL, NULL),
    ('is_public', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('total_reply_count', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('channel_id', 'STRING', 5, FALSE, TRUE, 'channels', 'id'),
    ('etag', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('kind', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('author_display_name', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('author_profile_image_url', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('author_channel_url', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('author_channel_id', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('text_display', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('text_original', 'STRING', 13, FALSE, FALSE, NULL, NULL),
    ('parent_id', 'STRING', 14, FALSE, TRUE, 'comments', 'id'),
    ('can_rate', 'BOOLEAN', 15, FALSE, FALSE, NULL, NULL),
    ('viewer_rating', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('like_count', 'BIGINT', 17, FALSE, FALSE, NULL, NULL),
    ('moderation_status', 'STRING', 18, FALSE, FALSE, NULL, NULL),
    ('published_at', 'TIMESTAMP', 19, FALSE, FALSE, NULL, NULL),
    ('updated_at', 'TIMESTAMP', 20, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'youtube_analytics' AND t.name = 'comments';

-- 7. Captions columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('start_ms', 'BIGINT', 1, TRUE, FALSE, NULL, NULL),
    ('video_id', 'STRING', 2, FALSE, TRUE, 'videos', 'id'),
    ('end_ms', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('duration_ms', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('text', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('language', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('track_kind', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('audio_track_type', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('is_cc', 'BOOLEAN', 10, FALSE, FALSE, NULL, NULL),
    ('is_large', 'BOOLEAN', 11, FALSE, FALSE, NULL, NULL),
    ('is_easy_reader', 'BOOLEAN', 12, FALSE, FALSE, NULL, NULL),
    ('is_draft', 'BOOLEAN', 13, FALSE, FALSE, NULL, NULL),
    ('is_auto_synced', 'BOOLEAN', 14, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 15, FALSE, FALSE, NULL, NULL),
    ('failure_reason', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('last_updated', 'TIMESTAMP', 17, FALSE, FALSE, NULL, NULL),
    ('etag', 'STRING', 18, FALSE, FALSE, NULL, NULL),
    ('kind', 'STRING', 19, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'youtube_analytics' AND t.name = 'captions';

