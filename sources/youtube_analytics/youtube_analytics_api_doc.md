# **YouTube Data API v3 Documentation**

## **Authorization**

- **Chosen method**: OAuth 2.0 with offline refresh token.
- **Base URL**: `https://www.googleapis.com/youtube/v3`
- **Auth placement**:
  - HTTP header: `Authorization: Bearer <access_token>`
- **Required scope for reading comments**: `https://www.googleapis.com/auth/youtube.force-ssl`
- **Other supported methods (not used by this connector)**:
  - API keys (for public data only; cannot read user-specific or channel-owned data).
  - Service accounts (only usable with YouTube Content ID API or domain-wide delegation, not for standard YouTube Data API).

### Token Refresh Flow

The connector stores **`client_id`**, **`client_secret`**, and **`refresh_token`** in the UC connection. At runtime, the connector exchanges the refresh token for a short-lived access token. The connector does **not** run user-facing OAuth flows.

**Token endpoint**: `https://oauth2.googleapis.com/token`

**Request** (POST, form-encoded):

```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "client_id=<CLIENT_ID>" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "refresh_token=<REFRESH_TOKEN>" \
  -d "grant_type=refresh_token"
```

**Response** (JSON):

```json
{
  "access_token": "ya29.a0AfH6SM...",
  "expires_in": 3600,
  "scope": "https://www.googleapis.com/auth/youtube.force-ssl",
  "token_type": "Bearer"
}
```

The connector should:
- Cache the access token and re-use it until expiry (default 3600 seconds).
- Re-fetch a new token when the current one is within ~60 seconds of expiry or upon receiving a 401 response.

Example authenticated request:

```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/commentThreads?part=snippet,replies&videoId=<VIDEO_ID>&maxResults=100"
```


## **Object List**

For the initial connector, we treat specific YouTube Data API v3 resources as **objects/tables**.
The object list is **static** (defined by the connector), not discovered dynamically from an API.

| Object Name | Description | Primary Endpoint | Ingestion Type |
|------------|-------------|------------------|----------------|
| `captions` | Caption track content with metadata | `GET /captions` + `GET /captions/{id}` (download) | `snapshot` |
| `channels` | Channel metadata | `GET /channels` | `snapshot` |
| `comments` | Top-level comments and their replies for a video | `GET /commentThreads` | `cdc` (upserts based on `updatedAt`) |
| `playlists` | Playlist metadata for a channel | `GET /playlists` | `snapshot` |
| `videos` | Video metadata for all videos in a channel | `GET /videos` (with discovery via `channels` + `playlistItems`) | `snapshot` |

**Connector scope**:
- `captions`: Fetches caption track metadata and downloads the full caption content for videos. Creates one row per caption cue (subtitle line). **Note**: Caption download only works for videos owned by the authenticated user. Optionally accepts `video_id` (defaults to all videos in channel).
- `channels`: Fetches channel metadata for one or more channels. Optionally accepts `channel_id` table option (defaults to authenticated user's channel).
- `comments`: Fetches all comments (top-level + replies) for videos. If `video_id` is provided, fetches comments for that specific video. If `video_id` is **not** provided, discovers all videos in the channel (using `channel_id` or authenticated user's channel) and fetches comments for all of them.
- `playlists`: Fetches all playlists for a channel. Optionally accepts `playlist_id` (fetches specific playlist) or `channel_id` (defaults to authenticated user's channel).
- `videos`: Discovers all videos for a channel via the uploads playlist, then fetches full metadata. Optionally accepts `channel_id` table option (defaults to authenticated user's channel).


## **Object Schema**

### General notes

- YouTube Data API returns JSON resources with nested structures.
- For the connector, we define **tabular schemas** per object, derived from the JSON representation.
- Nested JSON objects (e.g., `snippet`, `authorChannelId`) are modeled as **nested structures** rather than being fully flattened.

### `comments` object (primary table)

**Source endpoints**:
- Primary: `GET /commentThreads` — retrieves top-level comments (comment threads) for a video.
- Secondary: `GET /comments` — retrieves replies to a specific comment (when `totalReplyCount > 0`).

**Key behavior**:
- The `commentThreads.list` endpoint returns threads (top-level comments) along with a preview of replies.
- Each thread includes a `topLevelComment` (a full comment resource) and optionally a `replies` array.
- The `replies.comments` array may not include all replies; additional replies must be fetched via `comments.list` with `parentId`.
- The connector **flattens** the response into a single row per comment, combining thread-level fields (`videoId`, `canReply`, `totalReplyCount`, `isPublic`) with comment-level fields from `topLevelComment`.

**Table options**:
- `video_id` (optional): The YouTube video ID to fetch comments for. If provided, fetches comments for that specific video only. If **not** provided, discovers all videos in the channel and fetches comments for all of them.
- `channel_id` (optional): The channel ID to use when discovering videos (only used when `video_id` is not provided). Defaults to the authenticated user's channel (`mine=true`).
- `max_results` (optional): Page size for API pagination. Range 1-100, defaults to 100.
- `text_format` (optional): Format for comment text. Either `"plainText"` or `"html"`. Defaults to `"plainText"`.

**High-level schema (connector view)** — Flattened, matching Fivetran's approach:

| Column Name | Type | Source | Description |
|------------|------|--------|-------------|
| `id` | string | comment | **Primary key.** The unique ID of the comment. |
| `video_id` | string | commentThread | The video ID that this comment belongs to (`snippet.videoId`). |
| `channel_id` | string | comment | The YouTube channel associated with the comment (`topLevelComment.snippet.channelId`). |
| `etag` | string | comment | The ETag of the comment resource. |
| `kind` | string | comment | The resource type (`youtube#comment`). |
| `can_reply` | boolean | commentThread | Whether the current viewer can reply to this thread (`snippet.canReply`). |
| `is_public` | boolean | commentThread | Whether the thread is visible to all YouTube users (`snippet.isPublic`). |
| `total_reply_count` | integer | commentThread | Total number of replies to this comment (`snippet.totalReplyCount`). |
| `author_display_name` | string | comment | The display name of the user who posted the comment. |
| `author_profile_image_url` | string | comment | The URL for the avatar of the comment author. |
| `author_channel_url` | string | comment | The URL of the comment author's YouTube channel. |
| `author_channel_id` | string | comment | The ID of the comment author's YouTube channel (`authorChannelId.value`). |
| `text_display` | string | comment | The comment's text, possibly with HTML formatting. |
| `text_original` | string | comment | The original raw text of the comment. |
| `parent_id` | string or null | comment | The unique ID of the parent comment (null for top-level comments). |
| `can_rate` | boolean | comment | Whether the current viewer can rate the comment. |
| `viewer_rating` | string | comment | The rating the viewer has given (`like`, `none`). |
| `like_count` | integer | comment | The total number of likes on this comment. |
| `moderation_status` | string or null | comment | The moderation status (`heldForReview`, `likelySpam`, `published`, `rejected`). Only returned to channel/video owner. |
| `published_at` | string (ISO 8601 datetime) | comment | The date/time the comment was originally published. |
| `updated_at` | string (ISO 8601 datetime) | comment | The date/time the comment was last updated. **Used as cursor field for CDC.**|

**Example request**:

```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/commentThreads?part=snippet,replies&videoId=<VIDEO_ID>&maxResults=100&textFormat=plainText"
```

**Example API response (truncated)**:

```json
{
  "kind": "youtube#commentThreadListResponse",
  "etag": "grPOPMMjW...",
  "nextPageToken": "QURTSl9p...",
  "items": [
    {
      "kind": "youtube#commentThread",
      "etag": "abc123...",
      "id": "UgxKz1234567890abcdef",
      "snippet": {
        "channelId": "UCxxxxxxxxxx",
        "videoId": "dQw4w9WgXcQ",
        "topLevelComment": {
          "kind": "youtube#comment",
          "etag": "def456...",
          "id": "UgxKz1234567890abcdef",
          "snippet": {
            "channelId": "UCxxxxxxxxxx",
            "textDisplay": "Great video!",
            "textOriginal": "Great video!",
            "authorDisplayName": "John Doe",
            "authorProfileImageUrl": "https://yt3.ggpht.com/...",
            "authorChannelUrl": "http://www.youtube.com/channel/UCyyyyyyyy",
            "authorChannelId": { "value": "UCyyyyyyyy" },
            "canRate": true,
            "viewerRating": "none",
            "likeCount": 42,
            "publishedAt": "2024-01-15T10:30:00Z",
            "updatedAt": "2024-01-15T10:30:00Z"
          }
        },
        "canReply": true,
        "totalReplyCount": 3,
        "isPublic": true
      }
    }
  ]
}
```

**Example flattened connector record** (what the connector outputs):

```json
{
  "id": "UgxKz1234567890abcdef",
  "video_id": "dQw4w9WgXcQ",
  "channel_id": "UCxxxxxxxxxx",
  "etag": "def456...",
  "kind": "youtube#comment",
  "can_reply": true,
  "is_public": true,
  "total_reply_count": 3,
  "author_display_name": "John Doe",
  "author_profile_image_url": "https://yt3.ggpht.com/...",
  "author_channel_url": "http://www.youtube.com/channel/UCyyyyyyyy",
  "author_channel_id": "UCyyyyyyyy",
  "text_display": "Great video!",
  "text_original": "Great video!",
  "parent_id": null,
  "can_rate": true,
  "viewer_rating": "none",
  "like_count": 42,
  "moderation_status": null,
  "published_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```


### `videos` object

**Source endpoints** (3-step discovery + fetch):

1. `GET /channels` — Retrieve the channel's uploads playlist ID
2. `GET /playlistItems` — Enumerate all video IDs from the uploads playlist
3. `GET /videos` — Fetch full video metadata (batched, up to 50 IDs per request)

**Key behavior**:
- The connector discovers all videos for a channel by first fetching the channel's `relatedPlaylists.uploads` playlist ID.
- It then enumerates all video IDs in that playlist using `playlistItems.list`.
- Finally, it fetches full video metadata using `videos.list` with batched video IDs (up to 50 per request).
- The connector flattens nested structures (`snippet`, `contentDetails`, `statistics`, `status`, etc.) into a single row per video.

**Table options**:
- `channel_id` (optional): The channel ID to fetch videos from. If not provided, defaults to the authenticated user's channel (`mine=true`).

**High-level schema (connector view)** — Flattened:

| Column Name | Type | Source | Description |
|------------|------|--------|-------------|
| `id` | string | video | **Primary key.** The unique video ID. |
| `etag` | string | video | The ETag of the video resource. |
| `kind` | string | video | The resource type (`youtube#video`). |
| `published_at` | string (ISO 8601) | snippet | Date/time the video was published. |
| `channel_id` | string | snippet | ID of the channel that uploaded the video. |
| `title` | string | snippet | The video's title. |
| `description` | string | snippet | The video's description. |
| `channel_title` | string | snippet | Title of the channel that uploaded the video. |
| `tags` | array of strings | snippet | Tags associated with the video. |
| `category_id` | string | snippet | ID of the category the video belongs to. |
| `live_broadcast_content` | string | snippet | Live broadcast status: `none`, `upcoming`, `live`. |
| `default_language` | string | snippet | Language of the video's default metadata. |
| `default_audio_language` | string | snippet | Language of the default audio track. |
| `localized_title` | string | snippet.localized | Localized title. |
| `localized_description` | string | snippet.localized | Localized description. |
| `thumbnail_url` | string | snippet.thumbnails | URL of the highest-resolution thumbnail available. |
| `content_details_duration` | string | contentDetails | Duration in ISO 8601 format (e.g., `PT15M33S`). |
| `content_details_dimension` | string | contentDetails | Whether the video is `2d` or `3d`. |
| `content_details_definition` | string | contentDetails | Whether the video is `hd` or `sd`. |
| `content_details_caption` | string | contentDetails | Whether captions are available (`true`/`false`). |
| `content_details_licensed_content` | boolean | contentDetails | Whether the video is licensed content. |
| `content_details_projection` | string | contentDetails | Projection format: `rectangular` or `360`. |
| `content_details_has_custom_thumbnail` | boolean | contentDetails | Whether the video has a custom thumbnail. |
| `content_details_region_restriction_allowed` | array of strings | contentDetails.regionRestriction | Regions where the video is viewable. |
| `content_details_region_restriction_blocked` | array of strings | contentDetails.regionRestriction | Regions where the video is blocked. |
| `content_details_content_rating_mpaa` | string | contentDetails.contentRating | MPAA rating if applicable. |
| `content_details_content_rating_yt` | string | contentDetails.contentRating | YouTube rating if applicable. |
| `status_upload_status` | string | status | Upload status: `uploaded`, `processed`, `failed`, etc. |
| `status_failure_reason` | string | status | Reason for upload failure if applicable. |
| `status_rejection_reason` | string | status | Reason for rejection if applicable. |
| `status_privacy_status` | string | status | Privacy status: `public`, `private`, `unlisted`. |
| `status_publish_at` | string (ISO 8601) | status | Scheduled publish time for private videos. |
| `status_license` | string | status | License: `youtube` or `creativeCommon`. |
| `status_embeddable` | boolean | status | Whether the video can be embedded. |
| `status_public_stats_viewable` | boolean | status | Whether stats are publicly viewable. |
| `status_made_for_kids` | boolean | status | Whether the video is designated for kids. |
| `status_self_declared_made_for_kids` | boolean | status | Self-declared made-for-kids status. |
| `status_contains_synthetic_media` | boolean | status | Whether the video contains synthetic media. |
| `statistics_view_count` | long | statistics | Number of views. |
| `statistics_like_count` | long | statistics | Number of likes. |
| `statistics_favorite_count` | long | statistics | Number of favorites. |
| `statistics_comment_count` | long | statistics | Number of comments. |
| `player_embed_html` | string | player | HTML embed code for the video player. |
| `topic_details_topic_ids` | array of strings | topicDetails | Freebase topic IDs (deprecated). |
| `topic_details_relevant_topic_ids` | array of strings | topicDetails | Relevant Freebase topic IDs (deprecated). |
| `topic_details_topic_categories` | array of strings | topicDetails | Wikipedia URLs for topic categories. |
| `recording_details_recording_date` | string (ISO 8601) | recordingDetails | Date/time when the video was recorded. |
| `paid_product_placement_details_has_paid_product_placement` | boolean | paidProductPlacementDetails | Whether the video has paid product placement. |
| `live_streaming_details_actual_start_time` | string (ISO 8601) | liveStreamingDetails | Actual start time of live stream. |
| `live_streaming_details_actual_end_time` | string (ISO 8601) | liveStreamingDetails | Actual end time of live stream. |
| `live_streaming_details_scheduled_start_time` | string (ISO 8601) | liveStreamingDetails | Scheduled start time of live stream. |
| `live_streaming_details_scheduled_end_time` | string (ISO 8601) | liveStreamingDetails | Scheduled end time of live stream. |
| `live_streaming_details_concurrent_viewers` | long | liveStreamingDetails | Number of concurrent viewers during live stream. |
| `live_streaming_details_active_chat_id` | string | liveStreamingDetails | Active live chat ID. |

**Example discovery flow**:

```bash
# Step 1: Get channel's uploads playlist ID
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&mine=true"

# Response contains: relatedPlaylists.uploads = "UU..."

# Step 2: Enumerate video IDs from uploads playlist
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails&playlistId=UU...&maxResults=50"

# Response contains: items[].contentDetails.videoId

# Step 3: Fetch video metadata (batch up to 50 IDs)
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics,status,player,topicDetails,recordingDetails,liveStreamingDetails&id=VIDEO_ID1,VIDEO_ID2,..."
```

**Example API response for videos.list (truncated)**:

```json
{
  "kind": "youtube#videoListResponse",
  "etag": "xyz789...",
  "items": [
    {
      "kind": "youtube#video",
      "etag": "abc123...",
      "id": "dQw4w9WgXcQ",
      "snippet": {
        "publishedAt": "2009-10-25T06:57:33Z",
        "channelId": "UCuAXFkgsw1L7xaCfnd5JJOw",
        "title": "Rick Astley - Never Gonna Give You Up",
        "description": "The official video for...",
        "thumbnails": {
          "default": {"url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg"},
          "high": {"url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"},
          "maxres": {"url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"}
        },
        "channelTitle": "Rick Astley",
        "tags": ["rick astley", "never gonna give you up"],
        "categoryId": "10",
        "liveBroadcastContent": "none"
      },
      "contentDetails": {
        "duration": "PT3M33S",
        "dimension": "2d",
        "definition": "hd",
        "caption": "true",
        "licensedContent": true,
        "projection": "rectangular"
      },
      "statistics": {
        "viewCount": "1500000000",
        "likeCount": "15000000",
        "favoriteCount": "0",
        "commentCount": "3000000"
      },
      "status": {
        "uploadStatus": "processed",
        "privacyStatus": "public",
        "license": "youtube",
        "embeddable": true,
        "publicStatsViewable": true,
        "madeForKids": false
      }
    }
  ]
}
```


### `captions` object

**Source endpoints**:
- `GET /captions` — retrieves caption track metadata for a video (list).
- `GET /captions/{id}` — downloads the actual caption file content (download).

**Key behavior**:
- The connector first fetches caption track metadata using `captions.list` for a video.
- For each caption track, it downloads the full caption content using `captions.download` in SRT format.
- The SRT file is parsed to extract individual caption cues (start time, duration, text).
- **Important**: Caption download only works for videos owned by the authenticated user. Attempting to download captions for other users' videos will fail with a 403 error.
- Each caption cue becomes a separate row, combining track metadata with the parsed content.

**Table options**:
- `video_id` (optional): The video ID to fetch captions for. If not provided, discovers all videos in the channel and fetches captions for all of them.
- `channel_id` (optional): The channel ID (used when `video_id` is not provided). Defaults to the authenticated user's channel.

**High-level schema (connector view)** — One row per caption cue:

| Column Name | Type | Source | Description |
|------------|------|--------|-------------|
| `id` | string | captions.list | **Composite PK part 1.** The unique caption track ID. |
| `start_ms` | long | parsed content | **Composite PK part 2.** Start time of cue in milliseconds. |
| `video_id` | string | captions.list | The video this caption track belongs to. |
| `end_ms` | long | parsed content | End time of cue in milliseconds. |
| `duration_ms` | long | parsed content | Duration of cue in milliseconds (`end_ms - start_ms`). |
| `text` | string | parsed content | The caption text for this cue. |
| `language` | string | captions.list | BCP-47 language code of the caption track. |
| `name` | string | captions.list | Display name of the caption track. |
| `track_kind` | string | captions.list | Type: `ASR` (auto-generated), `forced`, or `standard`. |
| `audio_track_type` | string | captions.list | Audio type: `commentary`, `descriptive`, `primary`, `unknown`. |
| `is_cc` | boolean | captions.list | Whether track is closed captions for deaf/hard of hearing. |
| `is_large` | boolean | captions.list | Whether track uses large text for vision impaired. |
| `is_easy_reader` | boolean | captions.list | Whether track is third-grade level for language learners. |
| `is_draft` | boolean | captions.list | Whether track is a draft (not publicly visible). |
| `is_auto_synced` | boolean | captions.list | Whether YouTube auto-synced timing to audio. |
| `status` | string | captions.list | Track status: `serving`, `syncing`, `failed`. |
| `failure_reason` | string | captions.list | Why processing failed (if `status=failed`). |
| `last_updated` | timestamp | captions.list | When the caption track was last updated. |
| `etag` | string | captions.list | ETag of the caption track resource. |
| `kind` | string | captions.list | Resource kind (`youtube#caption`). |

**Example list request**:

```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/captions?part=snippet&videoId=<VIDEO_ID>"
```

**Example list response**:

```json
{
  "kind": "youtube#captionListResponse",
  "etag": "abc123...",
  "items": [
    {
      "kind": "youtube#caption",
      "etag": "def456...",
      "id": "AUieDaZ...",
      "snippet": {
        "videoId": "dQw4w9WgXcQ",
        "lastUpdated": "2024-01-15T10:30:00Z",
        "trackKind": "standard",
        "language": "en",
        "name": "English",
        "audioTrackType": "primary",
        "isCC": false,
        "isLarge": false,
        "isEasyReader": false,
        "isDraft": false,
        "isAutoSynced": false,
        "status": "serving"
      }
    }
  ]
}
```

**Example download request** (returns SRT format):

```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/captions/<CAPTION_ID>?tfmt=srt"
```

**Example SRT response**:

```
1
00:00:00,000 --> 00:00:02,500
Never gonna give you up

2
00:00:02,500 --> 00:00:05,000
Never gonna let you down

3
00:00:05,000 --> 00:00:08,500
Never gonna run around and desert you
```

**Example flattened connector records** (one per cue):

```json
[
  {
    "id": "AUieDaZ...",
    "start_ms": 0,
    "video_id": "dQw4w9WgXcQ",
    "end_ms": 2500,
    "duration_ms": 2500,
    "text": "Never gonna give you up",
    "language": "en",
    "name": "English",
    "track_kind": "standard",
    "audio_track_type": "primary",
    "is_cc": false,
    "is_large": false,
    "is_easy_reader": false,
    "is_draft": false,
    "is_auto_synced": false,
    "status": "serving",
    "failure_reason": null,
    "last_updated": "2024-01-15T10:30:00.000Z",
    "etag": "def456...",
    "kind": "youtube#caption"
  },
  {
    "id": "AUieDaZ...",
    "start_ms": 2500,
    "video_id": "dQw4w9WgXcQ",
    "end_ms": 5000,
    "duration_ms": 2500,
    "text": "Never gonna let you down",
    "language": "en",
    "name": "English",
    "track_kind": "standard",
    "audio_track_type": "primary",
    "is_cc": false,
    "is_large": false,
    "is_easy_reader": false,
    "is_draft": false,
    "is_auto_synced": false,
    "status": "serving",
    "failure_reason": null,
    "last_updated": "2024-01-15T10:30:00.000Z",
    "etag": "def456...",
    "kind": "youtube#caption"
  }
]
```


### `channels` object

**Source endpoint**:
- `GET /channels` — retrieves channel metadata for the authenticated user or a specified channel.

**Key behavior**:
- The connector fetches channel metadata using `channels.list` with all relevant parts.
- If `channel_id` is provided, fetches that specific channel. Otherwise, uses `mine=true` to fetch the authenticated user's channel.
- The connector flattens simple nested structures (`snippet.localized`, `contentOwnerDetails`) into individual fields.
- Complex nested structures (`status`, `brandingSettings`, `localizations`) are stored as JSON strings for flexibility.

**Table options**:
- `channel_id` (optional): The channel ID to fetch. If not provided, defaults to the authenticated user's channel (`mine=true`).

**High-level schema (connector view)** — Mixed flattening approach:

| Column Name | Type | Source | Description |
|------------|------|--------|-------------|
| `id` | string | channel | **Primary key.** The unique channel ID. |
| `etag` | string | channel | The ETag of the channel resource. |
| `kind` | string | channel | The resource type (`youtube#channel`). |
| `title` | string | snippet | The channel's title. |
| `description` | string | snippet | The channel's description. |
| `custom_url` | string | snippet | The channel's custom URL (handle). |
| `published_at` | string (ISO 8601) | snippet | Date/time the channel was created. |
| `country` | string | snippet | The country associated with the channel. |
| `thumbnail_url` | string | snippet.thumbnails | URL of the channel's thumbnail (high quality). |
| `default_language` | string | snippet | The language of the channel's default metadata. |
| `localized_title` | string | snippet.localized | Localized channel title. |
| `localized_description` | string | snippet.localized | Localized channel description. |
| `total_view_count` | long | statistics | Total views across all videos. |
| `total_subscriber_count` | long | statistics | Total subscriber count (rounded to 3 significant figures). |
| `total_video_count` | long | statistics | Total number of public videos. |
| `hidden_subscriber_count` | boolean | statistics | Whether the subscriber count is hidden. |
| `uploads_playlist_id` | string | contentDetails.relatedPlaylists | Playlist ID containing all uploaded videos. |
| `likes_playlist_id` | string | contentDetails.relatedPlaylists | Playlist ID containing liked videos (may be null). |
| `keywords` | string | brandingSettings.channel | Keywords associated with the channel. |
| `topic_categories` | array of strings | topicDetails | Wikipedia URLs describing channel topics. |
| `status` | string (JSON) | status | Channel status object as JSON (privacyStatus, isLinked, longUploadsStatus, madeForKids, selfDeclaredMadeForKids). |
| `branding_settings` | string (JSON) | brandingSettings | Channel branding settings as JSON. |
| `localizations` | string (JSON) | localizations | All localized metadata as JSON. |
| `content_owner_id` | string | contentOwnerDetails | Content owner ID (YouTube Partners only). |
| `content_owner_time_linked` | string (ISO 8601) | contentOwnerDetails | When the channel was linked to the content owner. |

**Example request**:

```bash
# Fetch authenticated user's channel
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails,statistics,topicDetails,status,brandingSettings,localizations,contentOwnerDetails&mine=true"

# Fetch specific channel by ID
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails,statistics,topicDetails,status,brandingSettings,localizations,contentOwnerDetails&id=UCxxxxxxxxxx"
```

**Example API response (truncated)**:

```json
{
  "kind": "youtube#channelListResponse",
  "etag": "abc123...",
  "items": [
    {
      "kind": "youtube#channel",
      "etag": "def456...",
      "id": "UCuAXFkgsw1L7xaCfnd5JJOw",
      "snippet": {
        "title": "Rick Astley",
        "description": "Official YouTube channel...",
        "customUrl": "@rickastley",
        "publishedAt": "2006-09-17T06:57:33Z",
        "thumbnails": {
          "default": {"url": "https://yt3.ggpht.com/.../default.jpg"},
          "high": {"url": "https://yt3.ggpht.com/.../high.jpg"}
        },
        "localized": {
          "title": "Rick Astley",
          "description": "Official YouTube channel..."
        },
        "country": "GB"
      },
      "contentDetails": {
        "relatedPlaylists": {
          "likes": "",
          "uploads": "UUuAXFkgsw1L7xaCfnd5JJOw"
        }
      },
      "statistics": {
        "viewCount": "2500000000",
        "subscriberCount": "15000000",
        "hiddenSubscriberCount": false,
        "videoCount": "150"
      },
      "topicDetails": {
        "topicCategories": [
          "https://en.wikipedia.org/wiki/Pop_music",
          "https://en.wikipedia.org/wiki/Music"
        ]
      },
      "status": {
        "privacyStatus": "public",
        "isLinked": true,
        "longUploadsStatus": "allowed",
        "madeForKids": false
      },
      "brandingSettings": {
        "channel": {
          "title": "Rick Astley",
          "description": "Official YouTube channel...",
          "keywords": "rick astley never gonna give you up",
          "unsubscribedTrailer": "dQw4w9WgXcQ"
        }
      }
    }
  ]
}
```

**Example flattened connector record**:

```json
{
  "id": "UCuAXFkgsw1L7xaCfnd5JJOw",
  "etag": "def456...",
  "kind": "youtube#channel",
  "title": "Rick Astley",
  "description": "Official YouTube channel...",
  "custom_url": "@rickastley",
  "published_at": "2006-09-17T06:57:33Z",
  "country": "GB",
  "thumbnail_url": "https://yt3.ggpht.com/.../high.jpg",
  "default_language": null,
  "localized_title": "Rick Astley",
  "localized_description": "Official YouTube channel...",
  "total_view_count": 2500000000,
  "total_subscriber_count": 15000000,
  "total_video_count": 150,
  "hidden_subscriber_count": false,
  "uploads_playlist_id": "UUuAXFkgsw1L7xaCfnd5JJOw",
  "likes_playlist_id": null,
  "keywords": "rick astley never gonna give you up",
  "topic_categories": ["https://en.wikipedia.org/wiki/Pop_music", "https://en.wikipedia.org/wiki/Music"],
  "status": "{\"privacyStatus\":\"public\",\"isLinked\":true,\"longUploadsStatus\":\"allowed\",\"madeForKids\":false}",
  "branding_settings": "{\"channel\":{\"title\":\"Rick Astley\",\"description\":\"Official YouTube channel...\",\"keywords\":\"rick astley never gonna give you up\"}}",
  "localizations": null,
  "content_owner_id": null,
  "content_owner_time_linked": null
}
```


### `playlists` object

**Source endpoint**:
- `GET /playlists` — retrieves playlist metadata for a channel or specific playlist(s).

**Key behavior**:
- The connector fetches playlist metadata using `playlists.list` with all relevant parts.
- If `playlist_id` is provided, fetches that specific playlist.
- If `channel_id` is provided (without `playlist_id`), fetches all playlists for that channel.
- If neither is provided, uses `mine=true` to fetch all playlists for the authenticated user.
- The connector flattens simple nested structures (`snippet.localized`) into individual fields.
- The `localizations` object is stored as a JSON string for flexibility.

**Table options**:
- `playlist_id` (optional): The playlist ID to fetch. If provided, fetches only this specific playlist.
- `channel_id` (optional): The channel ID to fetch playlists from. If not provided and `playlist_id` is not provided, defaults to the authenticated user's channel (`mine=true`).

**High-level schema (connector view)**:

| Column Name | Type | Source | Description |
|------------|------|--------|-------------|
| `id` | string | playlist | **Primary key.** The unique playlist ID. |
| `channel_id` | string | snippet | The channel ID that owns this playlist. |
| `title` | string | snippet | The playlist's title. |
| `description` | string | snippet | The playlist's description. |
| `published_at` | timestamp | snippet | When the playlist was created. |
| `total_item_count` | long | contentDetails | Number of videos in the playlist. |
| `podcast_status` | string | status | Podcast status: `enabled`, `disabled`, `unspecified`. |
| `privacy_status` | string | status | Privacy: `public`, `private`, `unlisted`. |
| `thumbnail_url` | string | snippet | URL of the high-quality thumbnail. |
| `channel_title` | string | snippet | Title of the channel that owns the playlist. |
| `default_language` | string | snippet | Default language for the playlist's metadata. |
| `player_embed_html` | string | player | HTML iframe tag to embed the playlist player. |
| `localized_title` | string | snippet.localized | Localized playlist title. |
| `localized_description` | string | snippet.localized | Localized playlist description. |
| `localizations` | string (JSON) | localizations | All localized metadata as JSON. |
| `kind` | string | playlist | Resource kind (`youtube#playlist`). |
| `etag` | string | playlist | ETag of the playlist resource. |

**Example list request**:

```bash
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/playlists?part=snippet,status,contentDetails,player,localizations&mine=true&maxResults=50"
```

**Example list response**:

```json
{
  "kind": "youtube#playlistListResponse",
  "etag": "abc123...",
  "pageInfo": {
    "totalResults": 5,
    "resultsPerPage": 50
  },
  "items": [
    {
      "kind": "youtube#playlist",
      "etag": "def456...",
      "id": "PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf",
      "snippet": {
        "publishedAt": "2020-05-15T10:30:00Z",
        "channelId": "UCuAXFkgsw1L7xaCfnd5JJOw",
        "title": "My Favorite Songs",
        "description": "A collection of my all-time favorite songs.",
        "thumbnails": {
          "default": { "url": "https://i.ytimg.com/vi/.../default.jpg", "width": 120, "height": 90 },
          "medium": { "url": "https://i.ytimg.com/vi/.../mqdefault.jpg", "width": 320, "height": 180 },
          "high": { "url": "https://i.ytimg.com/vi/.../hqdefault.jpg", "width": 480, "height": 360 }
        },
        "channelTitle": "Rick Astley",
        "defaultLanguage": "en",
        "localized": {
          "title": "My Favorite Songs",
          "description": "A collection of my all-time favorite songs."
        }
      },
      "status": {
        "privacyStatus": "public",
        "podcastStatus": "disabled"
      },
      "contentDetails": {
        "itemCount": 25
      },
      "player": {
        "embedHtml": "<iframe width=\"640\" height=\"360\" src=\"//www.youtube.com/embed/videoseries?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf\" frameborder=\"0\" allowfullscreen></iframe>"
      },
      "localizations": {
        "en": {
          "title": "My Favorite Songs",
          "description": "A collection of my all-time favorite songs."
        },
        "es": {
          "title": "Mis Canciones Favoritas",
          "description": "Una colección de mis canciones favoritas de todos los tiempos."
        }
      }
    }
  ]
}
```

**Example flattened connector record**:

```json
{
  "id": "PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf",
  "channel_id": "UCuAXFkgsw1L7xaCfnd5JJOw",
  "title": "My Favorite Songs",
  "description": "A collection of my all-time favorite songs.",
  "published_at": "2020-05-15T10:30:00.000Z",
  "total_item_count": 25,
  "podcast_status": "disabled",
  "privacy_status": "public",
  "thumbnail_url": "https://i.ytimg.com/vi/.../hqdefault.jpg",
  "channel_title": "Rick Astley",
  "default_language": "en",
  "player_embed_html": "<iframe width=\"640\" height=\"360\" src=\"//www.youtube.com/embed/videoseries?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf\" frameborder=\"0\" allowfullscreen></iframe>",
  "localized_title": "My Favorite Songs",
  "localized_description": "A collection of my all-time favorite songs.",
  "localizations": "{\"en\":{\"title\":\"My Favorite Songs\",\"description\":\"A collection...\"},\"es\":{\"title\":\"Mis Canciones Favoritas\",...}}",
  "kind": "youtube#playlist",
  "etag": "def456..."
}
```


## **Get Object Primary Keys**

There is no dedicated metadata endpoint to get primary keys. Primary keys are defined **statically** based on the resource schema.

| Object | Primary Key | Type | Source |
|--------|-------------|------|--------|
| `captions` | `id`, `start_ms` | string, long | Composite: caption track ID + cue start time |
| `channels` | `id` | string | `id` from the `channels.list` response |
| `comments` | `id` | string | `topLevelComment.id` from the `commentThreads` response |
| `playlists` | `id` | string | `id` from the `playlists.list` response |
| `videos` | `id` | string | `id` from the `videos.list` response |

The connector uses these as immutable primary keys for upserts/snapshots.


## **Object's ingestion type**

Supported ingestion types (framework-level definitions):
- `cdc`: Change data capture; supports upserts incrementally.
- `snapshot`: Full replacement snapshot; no inherent incremental support.
- `append`: Incremental but append-only (no updates/deletes).

| Object | Ingestion Type | Rationale |
|--------|----------------|-----------|
| `captions` | `snapshot` | Caption content can be updated. The connector re-syncs all caption content on each run. |
| `channels` | `snapshot` | Channel metadata (title, description, stats) can change at any time. The connector re-syncs channel metadata on each run. |
| `comments` | `cdc` | Comments have a stable primary key `id` and an `updatedAt` field that can be used as a cursor for incremental syncs. Comments can be edited by their authors, so updates are modeled as upserts. |
| `playlists` | `snapshot` | Playlist metadata can change at any time. The connector re-syncs all playlist metadata on each run. |
| `videos` | `snapshot` | Videos do not have a reliable `updatedAt` cursor. Video metadata (title, description, stats) can change at any time. The connector re-syncs all video metadata on each run. |

**For `captions`**:
- **Primary key**: `id`, `start_ms` (composite)
- **Cursor field**: None (snapshot)
- **Deletes**: Caption tracks that are deleted will not appear on subsequent syncs.

**For `channels`**:
- **Primary key**: `id`
- **Cursor field**: None (snapshot)
- **Deletes**: YouTube does not expose deleted channels via this API.

**For `comments`**:
- **Primary key**: `id`
- **Cursor field**: `updated_at` (from `topLevelComment.snippet.updatedAt`)
- **Sort order**: The API does not support sorting by `updatedAt`; the connector uses `order=time` (default, orders by `publishedAt` descending) for initial fetch, then relies on lookback windows for incremental.
- **Deletes**: YouTube does not expose deleted comments via this API; the connector treats the data as append/update only.

**For `playlists`**:
- **Primary key**: `id`
- **Cursor field**: None (snapshot)
- **Deletes**: YouTube does not expose deleted playlists via this API; playlists that are deleted will not appear on subsequent syncs.

**For `videos`**:
- **Primary key**: `id`
- **Cursor field**: None (snapshot)
- **Deletes**: YouTube does not expose deleted videos via this API; videos that disappear from the uploads playlist will not be returned on subsequent syncs.


## **Read API for Data Retrieval**

### Read endpoints for `captions`

The `captions` table requires a 2-step process: list metadata, then download content.

#### Step 1: List caption tracks

- **HTTP method**: `GET`
- **Endpoint**: `/captions`
- **Base URL**: `https://www.googleapis.com/youtube/v3`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `part` | string | yes | Use `snippet` to get metadata. |
| `videoId` | string | yes | The video ID to list captions for. |

**Response**: List of caption track resources with metadata.

#### Step 2: Download caption content

- **HTTP method**: `GET`
- **Endpoint**: `/captions/{id}`
- **Base URL**: `https://www.googleapis.com/youtube/v3`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | yes | The caption track ID (in URL path). |
| `tfmt` | string | no | Format: `sbv`, `srt`, `vtt`. Default varies. Use `srt` for parsing. |
| `tlang` | string | no | Target language for translation (optional). |

**Response**: Raw caption file content in the requested format.

**Important restrictions**:
- You can only download captions for videos **you own** (authenticated user must be video owner).
- Attempting to download captions for other users' videos returns 403 Forbidden.

**SRT format parsing**:

The connector requests `tfmt=srt` format and parses it using this structure:

```
{cue_number}
{start_time} --> {end_time}
{text}

```

Where:
- `start_time` / `end_time` format: `HH:MM:SS,mmm` (hours:minutes:seconds,milliseconds)
- `text` can span multiple lines until a blank line

**Example Python implementation**:

```python
import re

def parse_srt(srt_content: str) -> list[dict]:
    """Parse SRT content into list of cue dictionaries."""
    cues = []
    # Split by double newline (cue separator)
    blocks = re.split(r'\n\n+', srt_content.strip())
    
    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) < 2:
            continue
        
        # Skip cue number (first line)
        # Parse timestamp line (second line)
        timestamp_match = re.match(
            r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})',
            lines[1]
        )
        if not timestamp_match:
            continue
        
        # Convert to milliseconds
        start_ms = (
            int(timestamp_match.group(1)) * 3600000 +
            int(timestamp_match.group(2)) * 60000 +
            int(timestamp_match.group(3)) * 1000 +
            int(timestamp_match.group(4))
        )
        end_ms = (
            int(timestamp_match.group(5)) * 3600000 +
            int(timestamp_match.group(6)) * 60000 +
            int(timestamp_match.group(7)) * 1000 +
            int(timestamp_match.group(8))
        )
        
        # Text is everything after timestamp line
        text = '\n'.join(lines[2:])
        
        cues.append({
            'start_ms': start_ms,
            'end_ms': end_ms,
            'duration_ms': end_ms - start_ms,
            'text': text
        })
    
    return cues
```

**Quota costs**:
- `captions.list`: ~50 units per request
- `captions.download`: ~200 units per request

**Note**: Caption operations have higher quota costs than other endpoints. Monitor usage carefully.


### Primary read endpoint for `comments`

- **HTTP method**: `GET`
- **Endpoint**: `/commentThreads`
- **Base URL**: `https://www.googleapis.com/youtube/v3`

**Key query parameters** (relevant for ingestion):

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `part` | string | yes | – | Comma-separated list of resource properties to include. Use `snippet,replies` to get full data. |
| `videoId` | string | yes (filter) | – | The ID of the video whose comments should be retrieved. Required for this connector's MVP. |
| `maxResults` | integer | no | 20 | Number of results per page (max 100). |
| `pageToken` | string | no | – | Token for the next page of results. |
| `order` | string | no | `time` | Order of results: `time` (by date, most recent first) or `relevance`. |
| `textFormat` | string | no | `html` | Format of returned text: `html` or `plainText`. Recommend `plainText` for analytics. |
| `moderationStatus` | string | no | – | Filter by moderation status. Only usable by channel/video owner. Values: `heldForReview`, `likelySpam`, `published`. |

**Pagination strategy**:
- YouTube Data API uses token-based pagination with `pageToken` and `nextPageToken`.
- The connector should:
  - Request with `maxResults=100` (maximum) for efficiency.
  - Read `nextPageToken` from the response and use it in subsequent requests until absent.

**Example full pagination loop**:

```python
def fetch_all_comment_threads(access_token, video_id):
    base_url = "https://www.googleapis.com/youtube/v3/commentThreads"
    params = {
        "part": "snippet,replies",
        "videoId": video_id,
        "maxResults": 100,
        "textFormat": "plainText",
        "order": "time"
    }
    headers = {"Authorization": f"Bearer {access_token}"}
    
    all_items = []
    page_token = None
    
    while True:
        if page_token:
            params["pageToken"] = page_token
        
        response = requests.get(base_url, params=params, headers=headers)
        response.raise_for_status()
        data = response.json()
        
        all_items.extend(data.get("items", []))
        
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    
    return all_items
```

**Incremental strategy**:

The YouTube Data API **does not support a `since` or `updatedAfter` filter** on `commentThreads.list`. This means true incremental fetching based on `updatedAt` is not natively supported.

**Recommended approach for this connector**:
1. **Full scan with deduplication**: On each sync, fetch all comments for the video (paginate through all results).
2. **Track max `updatedAt`**: After processing, record the maximum `updatedAt` seen.
3. **Upsert semantics**: Use the comment `id` as primary key; downstream systems will handle upserts.
4. **Optional optimization**: For very large comment counts, consider tracking the last seen `publishedAt` and stopping pagination when reaching comments older than the last sync (assuming new comments are ordered first).

**Fetching all comments (top-level + replies)**:

The connector fetches **all comments** by combining two API calls:

1. **Top-level comments**: `GET /commentThreads?videoId=<VIDEO_ID>` - returns comment threads with `topLevelComment`
2. **Replies**: For each thread where `totalReplyCount > 0`, call `GET /comments?parentId=<COMMENT_ID>` to fetch all replies

**Important**: The `commentThreads` resource does NOT contain all replies - the `replies.comments` array is only a preview (up to 5). You MUST use `comments.list` with `parentId` to retrieve all replies.

```bash
# Fetch replies for a specific comment thread
curl -X GET \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://www.googleapis.com/youtube/v3/comments?part=snippet&parentId=<COMMENT_ID>&maxResults=100&textFormat=plainText"
```

**Flattened output**:
- Top-level comments: `parent_id = null`
- Replies: `parent_id = <top-level-comment-id>`
- For replies, thread-level fields (`video_id`, `can_reply`, `is_public`, `total_reply_count`) are inherited from the parent thread since the `comments` resource doesn't include them directly.


### Read endpoints for `videos`

The `videos` table requires a 3-step discovery and fetch process:

#### Step 1: Get uploads playlist ID

- **HTTP method**: `GET`
- **Endpoint**: `/channels`
- **Base URL**: `https://www.googleapis.com/youtube/v3`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `part` | string | yes | Use `contentDetails` to get playlist IDs. |
| `mine` | boolean | no | Set to `true` to get the authenticated user's channel. |
| `id` | string | no | Channel ID to fetch (alternative to `mine`). |

**Response**: `items[0].contentDetails.relatedPlaylists.uploads` contains the uploads playlist ID.

#### Step 2: Enumerate video IDs from uploads playlist

- **HTTP method**: `GET`
- **Endpoint**: `/playlistItems`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `part` | string | yes | Use `contentDetails` to get video IDs. |
| `playlistId` | string | yes | The uploads playlist ID from Step 1. |
| `maxResults` | integer | no | Max 50 per page. |
| `pageToken` | string | no | Token for pagination. |

**Response**: `items[].contentDetails.videoId` contains video IDs. Use `nextPageToken` for pagination.

#### Step 3: Fetch video metadata

- **HTTP method**: `GET`
- **Endpoint**: `/videos`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `part` | string | yes | Comma-separated parts: `snippet,contentDetails,statistics,status,player,topicDetails,recordingDetails,liveStreamingDetails`. |
| `id` | string | yes | Comma-separated video IDs (max 50). |

**Response**: Full video resources with all requested parts.

**Quota costs**:
- `channels.list`: ~1 unit
- `playlistItems.list`: ~1 unit per page
- `videos.list`: ~1 unit per request (up to 50 videos)

**Example Python implementation**:

```python
def fetch_all_videos_for_channel(access_token, channel_id=None):
    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = "https://www.googleapis.com/youtube/v3"
    
    # Step 1: Get uploads playlist ID
    params = {"part": "contentDetails"}
    if channel_id:
        params["id"] = channel_id
    else:
        params["mine"] = "true"
    
    resp = requests.get(f"{base_url}/channels", params=params, headers=headers)
    uploads_playlist_id = resp.json()["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    
    # Step 2: Enumerate all video IDs
    video_ids = []
    page_token = None
    while True:
        params = {"part": "contentDetails", "playlistId": uploads_playlist_id, "maxResults": 50}
        if page_token:
            params["pageToken"] = page_token
        resp = requests.get(f"{base_url}/playlistItems", params=params, headers=headers)
        data = resp.json()
        video_ids.extend([item["contentDetails"]["videoId"] for item in data.get("items", [])])
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    
    # Step 3: Fetch video metadata in batches of 50
    all_videos = []
    parts = "snippet,contentDetails,statistics,status,player,topicDetails,recordingDetails,liveStreamingDetails"
    for i in range(0, len(video_ids), 50):
        batch = video_ids[i:i+50]
        params = {"part": parts, "id": ",".join(batch)}
        resp = requests.get(f"{base_url}/videos", params=params, headers=headers)
        all_videos.extend(resp.json().get("items", []))
    
    return all_videos
```


### Read endpoint for `channels`

The `channels` table uses a single API call to fetch channel metadata.

- **HTTP method**: `GET`
- **Endpoint**: `/channels`
- **Base URL**: `https://www.googleapis.com/youtube/v3`

**Key query parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `part` | string | yes | – | Comma-separated list of resource properties. Use `snippet,contentDetails,statistics,topicDetails,status,brandingSettings,localizations,contentOwnerDetails` for full data. |
| `mine` | boolean | no | – | Set to `true` to get the authenticated user's channel. Cannot be used with `id`. |
| `id` | string | no | – | Comma-separated channel IDs to fetch (max 50). Cannot be used with `mine`. |

**Pagination**:
- The `channels.list` endpoint supports pagination via `pageToken` and `nextPageToken`.
- However, when fetching a single channel (via `mine=true` or a single `id`), pagination is not needed.
- For batch fetching multiple channels, use comma-separated IDs (max 50 per request).

**Example Python implementation**:

```python
def fetch_channel_metadata(access_token, channel_id=None):
    headers = {"Authorization": f"Bearer {access_token}"}
    base_url = "https://www.googleapis.com/youtube/v3"
    
    parts = "snippet,contentDetails,statistics,topicDetails,status,brandingSettings,localizations,contentOwnerDetails"
    params = {"part": parts}
    
    if channel_id:
        params["id"] = channel_id
    else:
        params["mine"] = "true"
    
    resp = requests.get(f"{base_url}/channels", params=params, headers=headers)
    resp.raise_for_status()
    data = resp.json()
    
    if not data.get("items"):
        raise ValueError("No channel found")
    
    return data["items"][0]
```

**Quota costs**:
- `channels.list`: ~1 unit per request

**Notes**:
- `contentOwnerDetails` is only returned for YouTube Partners with linked channels.
- `statistics.subscriberCount` is rounded to 3 significant figures by YouTube.
- `relatedPlaylists.likes` and `relatedPlaylists.favorites` may be empty or deprecated.


### Rate limits and quota

**YouTube Data API Quota**:
- Default quota: **10,000 units per day** per project.
- `commentThreads.list` costs approximately **1 unit per request** (for read operations).
- With 100 results per page, ~10,000 requests = ~1,000,000 comment threads per day (theoretical maximum).

**Best practices**:
- Use `maxResults=100` to minimize request count.
- Implement exponential backoff on 403 (quota exceeded) and 429 (rate limit) errors.
- Cache and re-use access tokens (avoid unnecessary token refresh calls).

**Error handling**:

| HTTP Status | Error | Description | Action |
|-------------|-------|-------------|--------|
| 400 | `badRequest` | Invalid parameter | Check parameters and fix |
| 401 | `unauthorized` | Invalid or expired token | Refresh access token and retry |
| 403 | `forbidden` | Quota exceeded or insufficient permissions | Wait and retry; check scopes |
| 403 | `commentsDisabled` | Comments are disabled for this video | Skip video, log warning |
| 404 | `videoNotFound` | Video does not exist | Skip video, log warning |
| 429 | – | Rate limit exceeded | Exponential backoff |


## **Field Type Mapping**

### General mapping (YouTube JSON → connector logical types)

| YouTube JSON Type | Example Fields | Connector Logical Type | Notes |
|------------------|----------------|------------------------|-------|
| string | `id`, `channel_id`, `video_id`, `text_display`, `text_original` | string | UTF-8 text. |
| string (enum) | `viewer_rating`, `moderation_status`, `kind` | string | Treated as string; valid values documented per field. |
| boolean | `can_rate`, `can_reply`, `is_public` | boolean | Standard true/false. |
| integer | `like_count`, `total_reply_count` | long / integer | For Spark-based connectors, prefer 64-bit integer (`LongType`). |
| string (ISO 8601 datetime) | `published_at`, `updated_at` | timestamp with timezone | Stored as UTC timestamps; parsing must respect timezone `Z`. |
| nullable fields | `parent_id`, `moderation_status` | corresponding type + null | When fields are absent, surface `null`. |

### Special behaviors and constraints

- `id` fields are opaque strings (not numeric); do not attempt to parse or cast.
- `published_at` and `updated_at` are always present for valid comments.
- `moderation_status` is only returned to the channel/video owner; for other users, it will be absent (treat as `null`).
- `text_original` may only be returned to the comment author; otherwise equals `text_display`.
- `parent_id` is `null` for top-level comments; set only for replies.


## **Known Quirks & Edge Cases**

- **Comments disabled**: Some videos have comments disabled. The API returns a 403 `commentsDisabled` error. The connector should catch this and skip the video gracefully.
- **Private/unlisted videos**: The API may return 404 for private videos or videos the authenticated user cannot access.
- **Reply fetching**: The `commentThreads` response only includes a preview of replies (up to 5). The connector must call `comments.list` with `parentId` to fetch all replies for threads where `totalReplyCount > 0`.
- **Some comments have no replies**: Check `totalReplyCount` before attempting to fetch replies to avoid unnecessary API calls.
- **No incremental filter**: The API does not support filtering by `updatedAt` or `since`. Full scans are required for true CDC.
- **Quota exhaustion**: 10,000 units/day is relatively limited for large-scale ingestion. Consider multiple projects or quota extensions for production use.
- **Rate limiting**: Beyond quota, Google may apply short-term rate limits. Implement exponential backoff.
- **Text formatting**: `text_display` may contain HTML even when `textFormat=plainText` is specified for certain edge cases (e.g., links). Downstream processing should handle this.


## **Research Log**

| Source Type | URL | Accessed (UTC) | Confidence | What it confirmed |
|------------|-----|----------------|------------|-------------------|
| Official Docs | https://developers.google.com/youtube/v3/docs/captions | 2026-01-09 | High | `caption` resource structure, properties, methods (list, download). |
| Official Docs | https://developers.google.com/youtube/v3/docs/captions/list | 2026-01-09 | High | `captions.list` endpoint parameters, returns track metadata. |
| Official Docs | https://developers.google.com/youtube/v3/docs/captions/download | 2026-01-09 | High | `captions.download` endpoint, format options (srt, vtt, sbv), owner-only restriction. |
| Official Docs | https://developers.google.com/youtube/v3/docs/commentThreads | 2026-01-08 | High | `commentThread` resource structure, properties, and methods. |
| Official Docs | https://developers.google.com/youtube/v3/docs/commentThreads/list | 2026-01-08 | High | `commentThreads.list` endpoint parameters, pagination, errors. |
| Official Docs | https://developers.google.com/youtube/v3/docs/comments | 2026-01-08 | High | `comment` resource structure and properties. |
| Official Docs | https://developers.google.com/youtube/v3/docs/comments/list | 2026-01-08 | High | `comments.list` endpoint for fetching replies. |
| Official Docs | https://developers.google.com/youtube/v3/docs/playlists | 2026-01-09 | High | `playlist` resource structure, properties, methods. |
| Official Docs | https://developers.google.com/youtube/v3/docs/playlists/list | 2026-01-09 | High | `playlists.list` endpoint parameters, `mine` vs `channelId` vs `id` filters. |
| Official Docs | https://developers.google.com/youtube/v3/docs/videos | 2026-01-08 | High | `video` resource structure and all available parts. |
| Official Docs | https://developers.google.com/youtube/v3/docs/videos/list | 2026-01-08 | High | `videos.list` endpoint parameters, batching up to 50 IDs. |
| Official Docs | https://developers.google.com/youtube/v3/docs/channels | 2026-01-09 | High | `channel` resource structure, all parts including snippet, statistics, brandingSettings, status, topicDetails, localizations, contentOwnerDetails. |
| Official Docs | https://developers.google.com/youtube/v3/docs/channels/list | 2026-01-09 | High | `channels.list` endpoint parameters, `mine` vs `id` filters. |
| Official Docs | https://developers.google.com/youtube/v3/docs/playlistItems | 2026-01-08 | High | `playlistItems.list` for enumerating video IDs from a playlist. |
| Official Docs | https://developers.google.com/identity/protocols/oauth2/web-server | 2026-01-08 | High | OAuth 2.0 token refresh flow and endpoint. |
| Official Docs | https://developers.google.com/youtube/v3/determine_quota_cost | 2026-01-08 | High | Quota costs and daily limits. |
| Fivetran Docs | https://fivetran.com/docs/connectors/applications/youtube-analytics | 2026-01-08 | High | Reference for how Fivetran models YouTube data; confirmed OAuth approach. |
| Fivetran ERD | User-provided screenshots | 2026-01-08 | Medium | Confirmed `comment` and `video` table structures from Fivetran's schema. |


## **Sources and References**

- **Official YouTube Data API v3 documentation** (highest confidence)
  - `https://developers.google.com/youtube/v3/docs`
  - `https://developers.google.com/youtube/v3/docs/captions`
  - `https://developers.google.com/youtube/v3/docs/captions/list`
  - `https://developers.google.com/youtube/v3/docs/captions/download`
  - `https://developers.google.com/youtube/v3/docs/channels`
  - `https://developers.google.com/youtube/v3/docs/channels/list`
  - `https://developers.google.com/youtube/v3/docs/commentThreads`
  - `https://developers.google.com/youtube/v3/docs/commentThreads/list`
  - `https://developers.google.com/youtube/v3/docs/comments`
  - `https://developers.google.com/youtube/v3/docs/comments/list`
  - `https://developers.google.com/youtube/v3/docs/playlists`
  - `https://developers.google.com/youtube/v3/docs/playlists/list`
- **Google OAuth 2.0 documentation** (highest confidence)
  - `https://developers.google.com/identity/protocols/oauth2/web-server`
- **Fivetran YouTube Analytics connector documentation** (high confidence)
  - `https://fivetran.com/docs/connectors/applications/youtube-analytics`
  - Used for reference on modeling and OAuth approach.

When conflicts arise, **official Google documentation** is treated as the source of truth.
