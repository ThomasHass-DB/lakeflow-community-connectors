# Lakeflow YouTube Analytics Community Connector

This documentation describes how to configure and use the **YouTube Analytics** Lakeflow community connector to ingest YouTube data (captions, channels, comments, playlists, and videos) via the YouTube Data API v3 into Databricks.

## Prerequisites

- **Google Cloud Project**: A Google Cloud project with the YouTube Data API v3 enabled.
- **OAuth 2.0 Credentials**: OAuth 2.0 client credentials (client ID and client secret) created in the Google Cloud Console.
- **Refresh Token**: A valid OAuth 2.0 refresh token obtained by completing the OAuth consent flow with the required scopes.
- **Required OAuth Scope**: `https://www.googleapis.com/auth/youtube.force-ssl` (allows read access to YouTube data, including caption download for owned videos).
- **Network access**: The environment running the connector must be able to reach `https://www.googleapis.com` and `https://oauth2.googleapis.com`.
- **Lakeflow / Databricks environment**: A workspace where you can register a Lakeflow community connector and run ingestion pipelines.

## Setup

### Required Connection Parameters

Provide the following **connection-level** options when configuring the connector:

| Name            | Type   | Required | Description                                                                 | Example                |
|-----------------|--------|----------|-----------------------------------------------------------------------------|------------------------|
| `client_id`     | string | yes      | OAuth 2.0 client ID from the Google Cloud Console.                         | `123456789-abc.apps.googleusercontent.com` |
| `client_secret` | string | yes      | OAuth 2.0 client secret from the Google Cloud Console.                     | `GOCSPX-xxx...`        |
| `refresh_token` | string | yes      | OAuth 2.0 refresh token obtained via the OAuth consent flow.               | `1//04xxx...`          |
| `externalOptionsAllowList` | string | yes | Comma-separated list of table-specific option names that are allowed to be passed through to the connector. | `video_id,max_results,text_format,channel_id,playlist_id` |

The full list of supported table-specific options for `externalOptionsAllowList` is:
`video_id,max_results,text_format,channel_id,playlist_id`

> **Note**: Table-specific options such as `video_id` are **not** connection parameters. They are provided per-table via table options in the pipeline specification. These option names must be included in `externalOptionsAllowList` for the connection to allow them.

### Obtaining OAuth 2.0 Credentials

#### Step 1: Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.
3. Enable the **YouTube Data API v3**:
   - Navigate to **APIs & Services → Library**.
   - Search for "YouTube Data API v3" and click **Enable**.

#### Step 2: Configure OAuth Consent Screen

1. In the Google Cloud Console, go to **APIs & Services → OAuth consent screen**.
2. Click **Get Started**.
3. Fill in the required information:
   - **App name**: A name for your application (e.g., "YouTube Connector")
   - **User support email**: Your email address
   - **Audience**: Select **External** (or Internal if within a Google Workspace organization)
   - **Contact information**: Your email address
4. Click **Continue** / **Save**.

#### Step 3: Create OAuth 2.0 Client

1. In the OAuth consent screen, go to **Clients** (or navigate to **APIs & Services → Credentials**).
2. Click **Create Client** (or **Create Credentials → OAuth client ID**).
3. Select application type: **Web application**.
4. Give it a name (e.g., "YouTube Connector Client").
5. Under **Authorized redirect URIs**, add: `https://developers.google.com/oauthplayground`
6. Click **Create**.
7. Download the credentials file or copy the **Client ID** and **Client Secret** from the confirmation dialog.

#### Step 4: Add Test Users

1. In the OAuth consent screen, go to **Audience**.
2. Click **Add users** under Test users.
3. Add the email address associated with your YouTube account (the account you'll use to authorize API access).
4. Click **Save**.

#### Step 5: Configure API Scopes

1. In the OAuth consent screen, go to **Data Access**.
2. Click **Add or remove scopes**.
3. Find and select: `https://www.googleapis.com/auth/youtube.force-ssl`
4. Click **Update** to save.

#### Step 6: Obtain a Refresh Token

1. Go to the [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/).
2. Click the **gear icon** (⚙️) in the top right.
3. Check **Use your own OAuth credentials**.
4. Enter your **Client ID** and **Client Secret**.
5. In the left panel, find **YouTube Data API v3** and select the scope:
   - `https://www.googleapis.com/auth/youtube.force-ssl`
6. Click **Authorize APIs** and complete the consent flow (sign in with the test user you added).
7. Click **Exchange authorization code for tokens**.
8. Copy the **Refresh Token** from the response.

### Create a Unity Catalog Connection

A Unity Catalog connection for this connector can be created in two ways via the UI:

1. Follow the **Lakeflow Community Connector** UI flow from the **Add Data** page.
2. Select any existing Lakeflow Community Connector connection for this source or create a new one.
3. Set `externalOptionsAllowList` to `video_id,max_results,text_format,channel_id,playlist_id` (required for this connector to pass table-specific options).

The connection can also be created using the standard Unity Catalog API.

## Supported Objects

The YouTube Analytics connector exposes a **static list** of tables:

- `captions`
- `channels`
- `comments`
- `playlists`
- `videos`

### Object Summary, Primary Keys, and Ingestion Mode

| Table      | Description                                                    | Ingestion Type | Primary Key        | Incremental Cursor |
|------------|----------------------------------------------------------------|----------------|--------------------|-------------------|
| `captions` | Caption track content (one row per subtitle cue)               | `snapshot`     | `id`, `start_ms`   | n/a               |
| `channels` | Channel metadata                                               | `snapshot`     | `id`               | n/a               |
| `comments` | All comments (top-level and replies) for a video or entire channel | `cdc`      | `id`               | `updated_at`      |
| `playlists`| All playlists for a channel                                    | `snapshot`     | `id`               | n/a               |
| `videos`   | All video metadata for a channel                               | `snapshot`     | `id`               | n/a               |

> **Note**: The `captions` table downloads and parses caption files. This only works for videos **owned by the authenticated user**. Attempting to fetch captions for other users' videos will skip those videos.

### Required and Optional Table Options

Table-specific options are passed via the pipeline spec under `table` in `objects`:

- **`captions`**:
  - `video_id` (string, optional): The video ID to fetch captions for. If not provided, discovers all videos in the channel and fetches captions for all owned videos.
  - `channel_id` (string, optional): The channel ID to use when discovering videos. Defaults to the authenticated user's channel.

- **`channels`**:
  - `channel_id` (string, optional): The channel ID to fetch. If not provided, defaults to the authenticated user's channel.

- **`comments`**:
  - `video_id` (string, optional): The YouTube video ID to fetch comments for. If not provided, fetches comments for **all videos** in the channel.
  - `channel_id` (string, optional): The channel ID to use when discovering videos (only used when `video_id` is not provided). Defaults to the authenticated user's channel.
  - `max_results` (integer, optional): Page size for API pagination. Range 1-100, defaults to 100.
  - `text_format` (string, optional): Format for comment text. Either `"plainText"` or `"html"`. Defaults to `"plainText"`.

- **`playlists`**:
  - `playlist_id` (string, optional): The playlist ID to fetch. If provided, fetches only this specific playlist.
  - `channel_id` (string, optional): The channel ID to fetch playlists from. If not provided, defaults to the authenticated user's channel.

- **`videos`**:
  - `channel_id` (string, optional): The channel ID to fetch videos from. If not provided, defaults to the authenticated user's channel.

### Schema Details

### `captions` Schema Details

The `captions` table contains one row per caption cue (subtitle line), combining track metadata with parsed content:

| Field                | Type      | Source         | Description                                           |
|----------------------|-----------|----------------|-------------------------------------------------------|
| `id`                 | string    | captions.list  | Caption track ID (composite PK part 1)                |
| `start_ms`           | long      | parsed SRT     | Start time in milliseconds (composite PK part 2)      |
| `video_id`           | string    | captions.list  | The video this caption track belongs to               |
| `end_ms`             | long      | parsed SRT     | End time in milliseconds                              |
| `duration_ms`        | long      | parsed SRT     | Duration of the cue in milliseconds                   |
| `text`               | string    | parsed SRT     | Caption text for this cue                             |
| `language`           | string    | captions.list  | BCP-47 language code (e.g., `en`, `es`)               |
| `name`               | string    | captions.list  | Display name of the caption track                     |
| `track_kind`         | string    | captions.list  | `ASR` (auto-generated), `forced`, or `standard`       |
| `audio_track_type`   | string    | captions.list  | `commentary`, `descriptive`, `primary`, `unknown`     |
| `is_cc`              | boolean   | captions.list  | Whether track is closed captions (for deaf/HOH)       |
| `is_large`           | boolean   | captions.list  | Whether track uses large text (vision impaired)       |
| `is_easy_reader`     | boolean   | captions.list  | Whether track is third-grade level                    |
| `is_draft`           | boolean   | captions.list  | Whether track is a draft (not publicly visible)       |
| `is_auto_synced`     | boolean   | captions.list  | Whether YouTube auto-synced timing                    |
| `status`             | string    | captions.list  | `serving`, `syncing`, or `failed`                     |
| `failure_reason`     | string    | captions.list  | Reason if status is `failed`                          |
| `last_updated`       | timestamp | captions.list  | When the caption track was last updated               |
| `etag`               | string    | captions.list  | ETag for caching                                      |
| `kind`               | string    | captions.list  | Resource kind (`youtube#caption`)                     |

### `comments` Schema Details

The `comments` table contains a flattened schema combining fields from both `commentThread` and `comment` resources:

| Field                      | Type    | Source            | Description                                                    |
|----------------------------|---------|-------------------|----------------------------------------------------------------|
| `id`                       | string  | comment           | Unique comment identifier (primary key)                        |
| `video_id`                 | string  | commentThread     | The video this comment belongs to                              |
| `can_reply`                | boolean | commentThread     | Whether replies are allowed                                    |
| `is_public`                | boolean | commentThread     | Whether the comment thread is public                           |
| `total_reply_count`        | long    | commentThread     | Number of replies (0 for reply comments)                       |
| `channel_id`               | string  | comment           | Channel that owns the video                                    |
| `etag`                     | string  | comment           | ETag for caching                                               |
| `kind`                     | string  | comment           | Resource kind (e.g., `youtube#comment`)                        |
| `author_display_name`      | string  | comment           | Comment author's display name                                  |
| `author_profile_image_url` | string  | comment           | URL of author's profile image                                  |
| `author_channel_url`       | string  | comment           | URL of author's channel                                        |
| `author_channel_id`        | string  | comment           | ID of author's channel                                         |
| `text_display`             | string  | comment           | Rendered comment text (may include HTML if `text_format=html`) |
| `text_original`            | string  | comment           | Original comment text as entered                               |
| `parent_id`                | string  | comment           | ID of parent comment (null for top-level comments)             |
| `can_rate`                 | boolean | comment           | Whether the viewer can rate this comment                       |
| `viewer_rating`            | string  | comment           | Viewer's rating (`like`, `dislike`, `none`)                    |
| `like_count`               | long    | comment           | Number of likes on this comment                                |
| `moderation_status`        | string  | comment           | Moderation status (if applicable)                              |
| `published_at`             | timestamp | comment         | Timestamp when comment was published                           |
| `updated_at`               | timestamp | comment         | Timestamp when comment was last updated (cursor)               |

### `playlists` Schema Details

The `playlists` table contains playlist metadata with localization support:

| Field                    | Type           | Description                                                    |
|--------------------------|----------------|----------------------------------------------------------------|
| `id`                     | string         | Unique playlist identifier (primary key)                       |
| `channel_id`             | string         | ID of the channel that owns the playlist                       |
| `title`                  | string         | Playlist title                                                 |
| `description`            | string         | Playlist description                                           |
| `published_at`           | timestamp      | Timestamp when playlist was created                            |
| `total_item_count`       | long           | Number of videos in the playlist                               |
| `podcast_status`         | string         | Podcast status: `enabled`, `disabled`, `unspecified`           |
| `privacy_status`         | string         | Privacy status: `public`, `private`, `unlisted`                |
| `thumbnail_url`          | string         | URL of the highest-resolution thumbnail                        |
| `channel_title`          | string         | Title of the channel that owns the playlist                    |
| `default_language`       | string         | Default language for playlist metadata                         |
| `player_embed_html`      | string         | HTML iframe tag to embed the playlist player                   |
| `localized_title`        | string         | Localized playlist title                                       |
| `localized_description`  | string         | Localized playlist description                                 |
| `localizations`          | string (JSON)  | All localized metadata as JSON                                 |
| `kind`                   | string         | Resource kind (`youtube#playlist`)                             |
| `etag`                   | string         | ETag for caching                                               |

### `videos` Schema Details

The `videos` table contains a flattened schema with metadata from all video resource parts:

| Field                      | Type           | Description                                                    |
|----------------------------|----------------|----------------------------------------------------------------|
| `id`                       | string         | Unique video identifier (primary key)                          |
| `etag`                     | string         | ETag for caching                                               |
| `kind`                     | string         | Resource kind (`youtube#video`)                                |
| `published_at`             | timestamp      | Timestamp when video was published                             |
| `channel_id`               | string         | ID of the channel that uploaded the video                      |
| `title`                    | string         | Video title                                                    |
| `description`              | string         | Video description                                              |
| `channel_title`            | string         | Title of the channel that uploaded the video                   |
| `tags`                     | array<string>  | Tags associated with the video                                 |
| `category_id`              | string         | ID of the video category                                       |
| `thumbnail_url`            | string         | URL of the highest-resolution thumbnail                        |
| `content_details_duration` | string         | Video duration in ISO 8601 format (e.g., `PT15M33S`)           |
| `content_details_definition` | string       | `hd` or `sd`                                                   |
| `statistics_view_count`    | long           | Number of views                                                |
| `statistics_like_count`    | long           | Number of likes                                                |
| `statistics_comment_count` | long           | Number of comments                                             |
| `status_privacy_status`    | string         | `public`, `private`, or `unlisted`                             |
| `status_made_for_kids`     | boolean        | Whether the video is designated for kids                       |
| `live_streaming_details_*` | various        | Live stream timing and viewer info (for live videos)           |

*See the full schema with 54 fields in the connector implementation.*

### `channels` Schema Details

The `channels` table contains a mixed schema with some fields flattened and some stored as JSON:

| Field                      | Type           | Description                                                    |
|----------------------------|----------------|----------------------------------------------------------------|
| `id`                       | string         | Unique channel identifier (primary key)                        |
| `etag`                     | string         | ETag for caching                                               |
| `kind`                     | string         | Resource kind (`youtube#channel`)                              |
| `title`                    | string         | Channel title                                                  |
| `description`              | string         | Channel description                                            |
| `custom_url`               | string         | Channel's custom URL (handle)                                  |
| `published_at`             | timestamp      | Timestamp when channel was created                             |
| `country`                  | string         | Country associated with the channel                            |
| `thumbnail_url`            | string         | URL of channel thumbnail (high quality)                        |
| `default_language`         | string         | Default metadata language                                      |
| `localized_title`          | string         | Localized channel title                                        |
| `localized_description`    | string         | Localized channel description                                  |
| `total_view_count`         | long           | Total views across all videos                                  |
| `total_subscriber_count`   | long           | Subscriber count (rounded to 3 significant figures)            |
| `total_video_count`        | long           | Total number of public videos                                  |
| `hidden_subscriber_count`  | boolean        | Whether subscriber count is hidden                             |
| `uploads_playlist_id`      | string         | Playlist ID containing all uploaded videos                     |
| `likes_playlist_id`        | string         | Playlist ID containing liked videos (may be null)              |
| `keywords`                 | string         | Keywords from branding settings                                |
| `topic_categories`         | array<string>  | Wikipedia URLs describing channel topics                       |
| `status`                   | string (JSON)  | Channel status object as JSON                                  |
| `branding_settings`        | string (JSON)  | Channel branding settings as JSON                              |
| `localizations`            | string (JSON)  | All localized metadata as JSON                                 |
| `content_owner_id`         | string         | Content owner ID (YouTube Partners only)                       |
| `content_owner_time_linked`| timestamp      | When channel was linked to content owner                       |

## Data Type Mapping

YouTube API JSON fields are mapped to Spark types as follows:

| YouTube JSON Type    | Example Fields                              | Spark Type          | Notes                                      |
|----------------------|---------------------------------------------|---------------------|--------------------------------------------|
| string               | `id`, `channelId`, `textDisplay`            | `StringType`        | Standard string mapping                    |
| boolean              | `canRate`, `canReply`, `isPublic`           | `BooleanType`       | Standard boolean mapping                   |
| unsigned integer     | `likeCount`, `viewCount`                    | `LongType`          | All integers use `LongType` to avoid overflow |
| ISO 8601 datetime    | `publishedAt`, `updatedAt`                  | `TimestampType`     | Automatically parsed from ISO 8601 UTC strings |
| array of strings     | `tags`, `topicCategories`                   | `ArrayType(StringType)` | Arrays preserved as nested collections |
| nested object        | `status`, `brandingSettings`                | `StringType` (JSON) | Complex objects serialized as JSON strings |

## How to Run

### Step 1: Clone/Copy the Source Connector Code

Use the Lakeflow Community Connector UI to copy or reference the YouTube Analytics connector source in your workspace.

### Step 2: Configure Your Pipeline

In your pipeline code, configure a `pipeline_spec` that references:

- A **Unity Catalog connection** configured with OAuth credentials.
- One or more **tables** to ingest, each with required `table_options`.

Example `pipeline_spec` snippet:

```json
{
  "pipeline_spec": {
    "connection_name": "youtube_connection",
    "object": [
      {
        "table": {
          "source_table": "captions"
        }
      },
      {
        "table": {
          "source_table": "channels"
        }
      },
      {
        "table": {
          "source_table": "comments",
          "video_id": "dQw4w9WgXcQ"
        }
      },
      {
        "table": {
          "source_table": "comments"
        }
      },
      {
        "table": {
          "source_table": "playlists"
        }
      },
      {
        "table": {
          "source_table": "videos"
        }
      }
    ]
  }
}
```

- `connection_name` must point to the UC connection configured with your OAuth credentials.
- For `captions`: Downloads and parses caption files for owned videos. Creates one row per caption cue.
  - If `video_id` is provided, fetches captions for that specific video.
  - If `video_id` is **not** provided, discovers all videos in the channel and fetches captions for all of them.
  - **Important**: Caption download only works for videos you own.
- For `channels`: No required options; defaults to the authenticated user's channel. Optionally provide `channel_id` to fetch a different channel.
- For `comments`: 
  - If `video_id` is provided, fetches comments for that specific video.
  - If `video_id` is **not** provided, discovers all videos in the channel and fetches comments for **all** of them (channel-wide mode).
- For `playlists`: No required options; defaults to the authenticated user's channel. Optionally provide `playlist_id` (specific playlist) or `channel_id` (different channel).
- For `videos`: No required options; defaults to the authenticated user's channel. Optionally provide `channel_id` to fetch videos from a different channel.

### Step 3: Run and Schedule the Pipeline

Run the pipeline using your standard Lakeflow / Databricks orchestration.

- For `captions`: Caption content is fetched and parsed on every run (snapshot ingestion).
  - Creates one row per caption cue with timing information and text.
  - Only works for videos owned by the authenticated user.
- For `channels`: Channel metadata is fetched on every run (snapshot ingestion).
- For `comments`: 
  - If `video_id` is specified, fetches all comments for that video. 
  - If `video_id` is not specified, discovers all videos in the channel and fetches comments for all of them.
  - On subsequent runs, the connector uses the stored cursor (`updated_at`) to support incremental sync patterns.
- For `playlists`: All playlist metadata is fetched on every run (snapshot ingestion).
- For `videos`: All video metadata is fetched on every run (snapshot ingestion). The connector discovers videos via the channel's uploads playlist.

#### Best Practices

- **Start small**: Test with a video that has a moderate number of comments to validate configuration.
- **Use incremental sync**: Rely on the `cdc` pattern with `updated_at` to minimize API calls on subsequent runs.
- **Respect quota limits**: The YouTube Data API has daily quota limits. Monitor usage in the Google Cloud Console.

#### Troubleshooting

**Common Issues:**

- **Authentication failures (`401`)**:
  - Verify that `client_id`, `client_secret`, and `refresh_token` are correct.
  - Ensure the refresh token has not been revoked or expired.
  - Check that your OAuth app is properly configured with test users (if in testing mode).
  
- **`403 Forbidden` - commentsDisabled**:
  - The video has comments disabled. The connector returns an empty result in this case.

- **`403 Forbidden` - captions not accessible**:
  - Caption download only works for videos you own. The connector silently skips videos where captions cannot be downloaded.
  
- **`403 Forbidden` - Access blocked**:
  - Your Google Cloud app may not be verified. Add your account as a test user in the OAuth consent screen.
  
- **`404 Not Found`**:
  - The specified `video_id` does not exist or is not accessible.
  
- **Quota exceeded**:
  - YouTube Data API has daily quota limits (typically 10,000 units per Google Cloud project).
  - Reduce sync frequency or request a quota increase in the Google Cloud Console.

## API Quota Information

> **Important**: The YouTube Data API quota is tied to **your Google Cloud project**, not to this connector or any third-party tool. Whether you use this connector, Fivetran, or any other solution, API calls consume quota from your own project.

### Default Quota
- **10,000 units per day** per Google Cloud project
- Resets at midnight Pacific Time

### Quota Costs by Operation

| Operation | Approx. Cost | Notes |
|-----------|--------------|-------|
| `playlists.list` | ~1 unit | Per page (up to 50 results) |
| `videos.list` | ~1 unit | Can batch up to 50 video IDs |
| `commentThreads.list` | ~1 unit | Per page (up to 100 results) |
| `channels.list` | ~1 unit | Per request |
| `captions.list` | ~50 units | Per video |
| `captions.download` | ~200 units | **Most expensive** - per track |

### Tips to Reduce Quota Usage

1. **Use specific `video_id`** instead of fetching comments/captions for entire channel
2. **Skip `captions` table** if you don't need transcript data (highest quota cost)
3. **Reduce sync frequency** - daily syncs instead of hourly
4. **Use incremental sync** for `comments` table (uses cursor to minimize re-fetching)

### Increasing Your Quota

To request a quota increase:
1. Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → YouTube Data API v3
2. Click "Quotas" → "Request increase"
3. Fill out the form explaining your use case
4. Wait for approval (typically 1-2 weeks)

Alternatively, create additional Google Cloud projects (each gets its own 10,000 unit quota).

## References

- Connector implementation: `sources/youtube_analytics/youtube_analytics.py`
- Connector API documentation: `sources/youtube_analytics/youtube_analytics_api_doc.md`
- Official YouTube Data API v3 documentation:
  - https://developers.google.com/youtube/v3/docs
  - https://developers.google.com/youtube/v3/docs/captions
  - https://developers.google.com/youtube/v3/docs/channels
  - https://developers.google.com/youtube/v3/docs/commentThreads
  - https://developers.google.com/youtube/v3/docs/comments
  - https://developers.google.com/youtube/v3/docs/playlistItems
  - https://developers.google.com/youtube/v3/docs/playlists
  - https://developers.google.com/youtube/v3/docs/videos
- Google OAuth 2.0:
  - https://developers.google.com/identity/protocols/oauth2
  - https://developers.google.com/oauthplayground/

