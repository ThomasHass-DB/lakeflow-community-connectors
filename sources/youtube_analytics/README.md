# Lakeflow YouTube Analytics Community Connector

This documentation describes how to configure and use the **YouTube Analytics** Lakeflow community connector to ingest YouTube data (comments and videos) via the YouTube Data API v3 into Databricks.

## Prerequisites

- **Google Cloud Project**: A Google Cloud project with the YouTube Data API v3 enabled.
- **OAuth 2.0 Credentials**: OAuth 2.0 client credentials (client ID and client secret) created in the Google Cloud Console.
- **Refresh Token**: A valid OAuth 2.0 refresh token obtained by completing the OAuth consent flow with the required scopes.
- **Required OAuth Scope**: `https://www.googleapis.com/auth/youtube.force-ssl` (allows read access to YouTube data).
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
| `externalOptionsAllowList` | string | yes | Comma-separated list of table-specific option names that are allowed to be passed through to the connector. | `video_id,max_results,text_format,channel_id` |

The full list of supported table-specific options for `externalOptionsAllowList` is:
`video_id,max_results,text_format,channel_id`

> **Note**: Table-specific options such as `video_id` are **not** connection parameters. They are provided per-table via table options in the pipeline specification. These option names must be included in `externalOptionsAllowList` for the connection to allow them.

### Obtaining OAuth 2.0 Credentials

#### Step 1: Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.
3. Enable the **YouTube Data API v3**:
   - Navigate to **APIs & Services → Library**.
   - Search for "YouTube Data API v3" and click **Enable**.

#### Step 2: Create OAuth 2.0 Credentials

1. In the Google Cloud Console, go to **APIs & Services → Credentials**.
2. Click **Create Credentials → OAuth client ID**.
3. If prompted, configure the **OAuth consent screen**:
   - Choose **External** (or Internal if within a Google Workspace organization).
   - Fill in the required app information.
   - Add the scope: `https://www.googleapis.com/auth/youtube.force-ssl`.
   - Add your email as a **test user** (required for apps in testing mode).
4. For application type, select **Web application**.
5. Add `https://developers.google.com/oauthplayground` as an **Authorized redirect URI**.
6. Click **Create** and note your **Client ID** and **Client Secret**.

#### Step 3: Obtain a Refresh Token

1. Go to the [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/).
2. Click the **gear icon** (settings) in the top right.
3. Check **Use your own OAuth credentials**.
4. Enter your **Client ID** and **Client Secret**.
5. In the left panel, find **YouTube Data API v3** and select the scope:
   - `https://www.googleapis.com/auth/youtube.force-ssl`
6. Click **Authorize APIs** and complete the consent flow.
7. Click **Exchange authorization code for tokens**.
8. Copy the **Refresh Token** from the response.

### Create a Unity Catalog Connection

A Unity Catalog connection for this connector can be created in two ways via the UI:

1. Follow the **Lakeflow Community Connector** UI flow from the **Add Data** page.
2. Select any existing Lakeflow Community Connector connection for this source or create a new one.
3. Set `externalOptionsAllowList` to `video_id,max_results,text_format,channel_id` (required for this connector to pass table-specific options).

The connection can also be created using the standard Unity Catalog API.

## Supported Objects

The YouTube Analytics connector exposes a **static list** of tables:

- `comments`
- `videos`

### Object Summary, Primary Keys, and Ingestion Mode

| Table      | Description                                                    | Ingestion Type | Primary Key | Incremental Cursor |
|------------|----------------------------------------------------------------|----------------|-------------|--------------------|
| `comments` | All comments (top-level and replies) for a specified video     | `cdc`          | `id`        | `updated_at`       |
| `videos`   | All video metadata for a channel                               | `snapshot`     | `id`        | n/a                |

### Required and Optional Table Options

Table-specific options are passed via the pipeline spec under `table` in `objects`:

- **`comments`**:
  - `video_id` (string, **required**): The YouTube video ID to fetch comments for.
  - `max_results` (integer, optional): Page size for API pagination. Range 1-100, defaults to 100.
  - `text_format` (string, optional): Format for comment text. Either `"plainText"` or `"html"`. Defaults to `"plainText"`.

- **`videos`**:
  - `channel_id` (string, optional): The channel ID to fetch videos from. If not provided, defaults to the authenticated user's channel.

### Schema Details

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
| `published_at`             | string  | comment           | ISO 8601 timestamp when comment was published                  |
| `updated_at`               | string  | comment           | ISO 8601 timestamp when comment was last updated (cursor)      |

### `videos` Schema Details

The `videos` table contains a flattened schema with metadata from all video resource parts:

| Field                      | Type           | Description                                                    |
|----------------------------|----------------|----------------------------------------------------------------|
| `id`                       | string         | Unique video identifier (primary key)                          |
| `etag`                     | string         | ETag for caching                                               |
| `kind`                     | string         | Resource kind (`youtube#video`)                                |
| `published_at`             | string         | ISO 8601 timestamp when video was published                    |
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

## Data Type Mapping

YouTube API JSON fields are mapped to Spark types as follows:

| YouTube JSON Type    | Example Fields                              | Spark Type          | Notes                                      |
|----------------------|---------------------------------------------|---------------------|--------------------------------------------|
| string               | `id`, `channelId`, `textDisplay`            | `StringType`        | Standard string mapping                    |
| boolean              | `canRate`, `canReply`, `isPublic`           | `BooleanType`       | Standard boolean mapping                   |
| unsigned integer     | `likeCount`, `viewCount`                    | `LongType`          | All integers use `LongType` to avoid overflow |
| ISO 8601 datetime    | `publishedAt`, `updatedAt`                  | `StringType`        | Stored as UTC strings; can be cast downstream |
| array of strings     | `tags`, `topicCategories`                   | `ArrayType(StringType)` | Arrays preserved as nested collections |

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
          "source_table": "comments",
          "video_id": "dQw4w9WgXcQ"
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
- For `comments`: `video_id` is required and specifies which YouTube video to fetch comments from.
- For `videos`: No required options; defaults to the authenticated user's channel. Optionally provide `channel_id` to fetch videos from a different channel.

### Step 3: Run and Schedule the Pipeline

Run the pipeline using your standard Lakeflow / Databricks orchestration.

- For `comments`: On the first run, all comments for the video are fetched. On subsequent runs, the connector uses the stored cursor (`updated_at`) to support incremental sync patterns.
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
  
- **`403 Forbidden` - Access blocked**:
  - Your Google Cloud app may not be verified. Add your account as a test user in the OAuth consent screen.
  
- **`404 Not Found`**:
  - The specified `video_id` does not exist or is not accessible.
  
- **Quota exceeded**:
  - YouTube Data API has daily quota limits (typically 10,000 units). Each `commentThreads.list` call costs ~1 unit.
  - Reduce sync frequency or request a quota increase in the Google Cloud Console.

## References

- Connector implementation: `sources/youtube_analytics/youtube_analytics.py`
- Connector API documentation: `sources/youtube_analytics/youtube_analytics_api_doc.md`
- Official YouTube Data API v3 documentation:
  - https://developers.google.com/youtube/v3/docs
  - https://developers.google.com/youtube/v3/docs/commentThreads
  - https://developers.google.com/youtube/v3/docs/comments
  - https://developers.google.com/youtube/v3/docs/videos
  - https://developers.google.com/youtube/v3/docs/channels
  - https://developers.google.com/youtube/v3/docs/playlistItems
- Google OAuth 2.0:
  - https://developers.google.com/identity/protocols/oauth2
  - https://developers.google.com/oauthplayground/

