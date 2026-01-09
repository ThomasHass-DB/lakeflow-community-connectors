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
| `comments` | Top-level comments and their replies for a video | `GET /commentThreads` | `cdc` (upserts based on `updatedAt`) |
| `videos` | Video metadata for all videos in a channel | `GET /videos` (with discovery via `channels` + `playlistItems`) | `snapshot` |

**Connector scope**:
- `comments`: Fetches all comments (top-level + replies) for videos. If `video_id` is provided, fetches comments for that specific video. If `video_id` is **not** provided, discovers all videos in the channel (using `channel_id` or authenticated user's channel) and fetches comments for all of them.
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


## **Get Object Primary Keys**

There is no dedicated metadata endpoint to get primary keys. Primary keys are defined **statically** based on the resource schema.

| Object | Primary Key | Type | Source |
|--------|-------------|------|--------|
| `comments` | `id` | string | `topLevelComment.id` from the `commentThreads` response |
| `videos` | `id` | string | `id` from the `videos.list` response |

The connector uses these as immutable primary keys for upserts/snapshots.


## **Object's ingestion type**

Supported ingestion types (framework-level definitions):
- `cdc`: Change data capture; supports upserts incrementally.
- `snapshot`: Full replacement snapshot; no inherent incremental support.
- `append`: Incremental but append-only (no updates/deletes).

| Object | Ingestion Type | Rationale |
|--------|----------------|-----------|
| `comments` | `cdc` | Comments have a stable primary key `id` and an `updatedAt` field that can be used as a cursor for incremental syncs. Comments can be edited by their authors, so updates are modeled as upserts. |
| `videos` | `snapshot` | Videos do not have a reliable `updatedAt` cursor. Video metadata (title, description, stats) can change at any time. The connector re-syncs all video metadata on each run. |

**For `comments`**:
- **Primary key**: `id`
- **Cursor field**: `updated_at` (from `topLevelComment.snippet.updatedAt`)
- **Sort order**: The API does not support sorting by `updatedAt`; the connector uses `order=time` (default, orders by `publishedAt` descending) for initial fetch, then relies on lookback windows for incremental.
- **Deletes**: YouTube does not expose deleted comments via this API; the connector treats the data as append/update only.

**For `videos`**:
- **Primary key**: `id`
- **Cursor field**: None (snapshot)
- **Deletes**: YouTube does not expose deleted videos via this API; videos that disappear from the uploads playlist will not be returned on subsequent syncs.


## **Read API for Data Retrieval**

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
| Official Docs | https://developers.google.com/youtube/v3/docs/commentThreads | 2026-01-08 | High | `commentThread` resource structure, properties, and methods. |
| Official Docs | https://developers.google.com/youtube/v3/docs/commentThreads/list | 2026-01-08 | High | `commentThreads.list` endpoint parameters, pagination, errors. |
| Official Docs | https://developers.google.com/youtube/v3/docs/comments | 2026-01-08 | High | `comment` resource structure and properties. |
| Official Docs | https://developers.google.com/youtube/v3/docs/comments/list | 2026-01-08 | High | `comments.list` endpoint for fetching replies. |
| Official Docs | https://developers.google.com/youtube/v3/docs/videos | 2026-01-08 | High | `video` resource structure and all available parts. |
| Official Docs | https://developers.google.com/youtube/v3/docs/videos/list | 2026-01-08 | High | `videos.list` endpoint parameters, batching up to 50 IDs. |
| Official Docs | https://developers.google.com/youtube/v3/docs/channels | 2026-01-08 | High | `channel` resource; `contentDetails.relatedPlaylists.uploads` for discovery. |
| Official Docs | https://developers.google.com/youtube/v3/docs/playlistItems | 2026-01-08 | High | `playlistItems.list` for enumerating video IDs from a playlist. |
| Official Docs | https://developers.google.com/identity/protocols/oauth2/web-server | 2026-01-08 | High | OAuth 2.0 token refresh flow and endpoint. |
| Official Docs | https://developers.google.com/youtube/v3/determine_quota_cost | 2026-01-08 | High | Quota costs and daily limits. |
| Fivetran Docs | https://fivetran.com/docs/connectors/applications/youtube-analytics | 2026-01-08 | High | Reference for how Fivetran models YouTube data; confirmed OAuth approach. |
| Fivetran ERD | User-provided screenshots | 2026-01-08 | Medium | Confirmed `comment` and `video` table structures from Fivetran's schema. |


## **Sources and References**

- **Official YouTube Data API v3 documentation** (highest confidence)
  - `https://developers.google.com/youtube/v3/docs`
  - `https://developers.google.com/youtube/v3/docs/commentThreads`
  - `https://developers.google.com/youtube/v3/docs/commentThreads/list`
  - `https://developers.google.com/youtube/v3/docs/comments`
  - `https://developers.google.com/youtube/v3/docs/comments/list`
- **Google OAuth 2.0 documentation** (highest confidence)
  - `https://developers.google.com/identity/protocols/oauth2/web-server`
- **Fivetran YouTube Analytics connector documentation** (high confidence)
  - `https://fivetran.com/docs/connectors/applications/youtube-analytics`
  - Used for reference on modeling and OAuth approach.

When conflicts arise, **official Google documentation** is treated as the source of truth.
