# pylint: disable=too-many-lines
"""YouTube Analytics connector using YouTube Data API v3."""

import time
from typing import Iterator, Any

import requests
from pyspark.sql.types import (
    StructType,
    StructField,
    ArrayType,
    LongType,
    StringType,
    BooleanType,
)


class LakeflowConnect:
    """
    YouTube Data API v3 connector for fetching comments and videos.

    This connector uses OAuth 2.0 with refresh token authentication.
    The UC connection must provide: client_id, client_secret, refresh_token.

    Supported tables:
        - comments: All comments (top-level + replies) for videos. If video_id is
          provided, fetches comments for that video only. Otherwise, discovers all
          videos for the channel and fetches comments for all of them.
        - videos: All video metadata for a channel. Optionally accepts channel_id.
    """

    # Google OAuth token endpoint
    TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
    # YouTube Data API base URL
    BASE_URL = "https://www.googleapis.com/youtube/v3"

    def __init__(self, options: dict[str, str]) -> None:
        """
        Initialize the YouTube Analytics connector with connection-level options.

        Expected options:
            - client_id: OAuth 2.0 client ID
            - client_secret: OAuth 2.0 client secret
            - refresh_token: OAuth 2.0 refresh token (obtained via OAuth flow)
        """
        self._client_id = options.get("client_id")
        self._client_secret = options.get("client_secret")
        self._refresh_token = options.get("refresh_token")

        if not self._client_id:
            raise ValueError("YouTube connector requires 'client_id' in options")
        if not self._client_secret:
            raise ValueError("YouTube connector requires 'client_secret' in options")
        if not self._refresh_token:
            raise ValueError("YouTube connector requires 'refresh_token' in options")

        # Access token cache
        self._access_token: str | None = None
        self._token_expiry: float = 0

        # Configure a session
        self._session = requests.Session()

    def _ensure_access_token(self) -> str:
        """
        Ensure we have a valid access token, refreshing if necessary.

        Returns the current valid access token.
        """
        # Refresh if token is missing or expiring within 60 seconds
        if self._access_token is None or time.time() >= (self._token_expiry - 60):
            self._refresh_access_token()
        return self._access_token

    def _refresh_access_token(self) -> None:
        """Exchange refresh token for a new access token."""
        response = self._session.post(
            self.TOKEN_ENDPOINT,
            data={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "refresh_token": self._refresh_token,
                "grant_type": "refresh_token",
            },
            timeout=30,
        )

        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to refresh access token: {response.status_code} {response.text}"
            )

        token_data = response.json()
        self._access_token = token_data.get("access_token")
        expires_in = token_data.get("expires_in", 3600)
        self._token_expiry = time.time() + expires_in

        if not self._access_token:
            raise RuntimeError("No access_token in token response")

    def _get_headers(self) -> dict[str, str]:
        """Get HTTP headers with valid Bearer token."""
        token = self._ensure_access_token()
        return {"Authorization": f"Bearer {token}"}

    def list_tables(self) -> list[str]:
        """
        List names of all tables supported by this connector.
        """
        return ["comments", "videos"]

    def _get_comments_schema(self) -> StructType:
        """Return the flattened comments table schema."""
        return StructType(
            [
                # Primary key
                StructField("id", StringType(), False),
                # Thread-level fields (from commentThread)
                StructField("video_id", StringType(), False),
                StructField("can_reply", BooleanType(), True),
                StructField("is_public", BooleanType(), True),
                StructField("total_reply_count", LongType(), True),
                # Comment-level fields (from topLevelComment or reply)
                StructField("channel_id", StringType(), True),
                StructField("etag", StringType(), True),
                StructField("kind", StringType(), True),
                StructField("author_display_name", StringType(), True),
                StructField("author_profile_image_url", StringType(), True),
                StructField("author_channel_url", StringType(), True),
                StructField("author_channel_id", StringType(), True),
                StructField("text_display", StringType(), True),
                StructField("text_original", StringType(), True),
                StructField("parent_id", StringType(), True),
                StructField("can_rate", BooleanType(), True),
                StructField("viewer_rating", StringType(), True),
                StructField("like_count", LongType(), True),
                StructField("moderation_status", StringType(), True),
                StructField("published_at", StringType(), True),
                StructField("updated_at", StringType(), True),
            ]
        )

    def _get_videos_schema(self) -> StructType:
        """Return the flattened videos table schema."""
        return StructType(
            [
                # Primary key and core fields
                StructField("id", StringType(), False),
                StructField("etag", StringType(), True),
                StructField("kind", StringType(), True),
                # Snippet fields
                StructField("published_at", StringType(), True),
                StructField("channel_id", StringType(), True),
                StructField("title", StringType(), True),
                StructField("description", StringType(), True),
                StructField("channel_title", StringType(), True),
                StructField("tags", ArrayType(StringType()), True),
                StructField("category_id", StringType(), True),
                StructField("live_broadcast_content", StringType(), True),
                StructField("default_language", StringType(), True),
                StructField("default_audio_language", StringType(), True),
                StructField("localized_title", StringType(), True),
                StructField("localized_description", StringType(), True),
                StructField("thumbnail_url", StringType(), True),
                # Content details
                StructField("content_details_duration", StringType(), True),
                StructField("content_details_dimension", StringType(), True),
                StructField("content_details_definition", StringType(), True),
                StructField("content_details_caption", StringType(), True),
                StructField("content_details_licensed_content", BooleanType(), True),
                StructField("content_details_projection", StringType(), True),
                StructField("content_details_has_custom_thumbnail", BooleanType(), True),
                StructField(
                    "content_details_region_restriction_allowed",
                    ArrayType(StringType()),
                    True,
                ),
                StructField(
                    "content_details_region_restriction_blocked",
                    ArrayType(StringType()),
                    True,
                ),
                StructField("content_details_content_rating_mpaa", StringType(), True),
                StructField("content_details_content_rating_yt", StringType(), True),
                # Status fields
                StructField("status_upload_status", StringType(), True),
                StructField("status_failure_reason", StringType(), True),
                StructField("status_rejection_reason", StringType(), True),
                StructField("status_privacy_status", StringType(), True),
                StructField("status_publish_at", StringType(), True),
                StructField("status_license", StringType(), True),
                StructField("status_embeddable", BooleanType(), True),
                StructField("status_public_stats_viewable", BooleanType(), True),
                StructField("status_made_for_kids", BooleanType(), True),
                StructField("status_self_declared_made_for_kids", BooleanType(), True),
                StructField("status_contains_synthetic_media", BooleanType(), True),
                # Statistics
                StructField("statistics_view_count", LongType(), True),
                StructField("statistics_like_count", LongType(), True),
                StructField("statistics_favorite_count", LongType(), True),
                StructField("statistics_comment_count", LongType(), True),
                # Player
                StructField("player_embed_html", StringType(), True),
                # Topic details
                StructField("topic_details_topic_ids", ArrayType(StringType()), True),
                StructField(
                    "topic_details_relevant_topic_ids", ArrayType(StringType()), True
                ),
                StructField(
                    "topic_details_topic_categories", ArrayType(StringType()), True
                ),
                # Recording details
                StructField("recording_details_recording_date", StringType(), True),
                # Paid product placement
                StructField(
                    "paid_product_placement_details_has_paid_product_placement",
                    BooleanType(),
                    True,
                ),
                # Live streaming details
                StructField(
                    "live_streaming_details_actual_start_time", StringType(), True
                ),
                StructField(
                    "live_streaming_details_actual_end_time", StringType(), True
                ),
                StructField(
                    "live_streaming_details_scheduled_start_time", StringType(), True
                ),
                StructField(
                    "live_streaming_details_scheduled_end_time", StringType(), True
                ),
                StructField(
                    "live_streaming_details_concurrent_viewers", LongType(), True
                ),
                StructField(
                    "live_streaming_details_active_chat_id", StringType(), True
                ),
            ]
        )

    def get_table_schema(
        self, table_name: str, table_options: dict[str, str]
    ) -> StructType:
        """
        Fetch the schema of a table.

        The schema is static and derived from the YouTube Data API documentation.
        """
        if table_name not in self.list_tables():
            raise ValueError(f"Unsupported table: {table_name!r}")

        if table_name == "comments":
            return self._get_comments_schema()
        if table_name == "videos":
            return self._get_videos_schema()

        raise ValueError(f"Unsupported table: {table_name!r}")

    def read_table_metadata(
        self, table_name: str, table_options: dict[str, str]
    ) -> dict:
        """
        Fetch metadata for the given table.

        For `comments`:
            - ingestion_type: cdc
            - primary_keys: ["id"]
            - cursor_field: updated_at

        For `videos`:
            - ingestion_type: snapshot
            - primary_keys: ["id"]
        """
        if table_name not in self.list_tables():
            raise ValueError(f"Unsupported table: {table_name!r}")

        if table_name == "comments":
            return {
                "primary_keys": ["id"],
                "cursor_field": "updated_at",
                "ingestion_type": "cdc",
            }
        if table_name == "videos":
            return {
                "primary_keys": ["id"],
                "ingestion_type": "snapshot",
            }

        raise ValueError(f"Unsupported table: {table_name!r}")

    def read_table(
        self, table_name: str, start_offset: dict, table_options: dict[str, str]
    ) -> (Iterator[dict], dict):
        """
        Read records from a table and return raw JSON-like dictionaries.

        For the `comments` table:
            - If video_id is provided, fetches comments for that specific video.
            - If video_id is NOT provided, discovers all videos for the channel
              (using channel_id or authenticated user's channel) and fetches
              comments for all of them.
            - For each video, fetches all comment threads and their replies.
            - Combines top-level comments and replies into a single flattened output.

        Optional table_options for `comments`:
            - video_id: The YouTube video ID to fetch comments for. If not
              provided, fetches comments for all videos in the channel.
            - channel_id: The channel ID (used when video_id is not provided).
              Defaults to authenticated user's channel.
            - max_results: Page size for API calls (max 100, default 100).
            - text_format: 'plainText' or 'html' (default 'plainText').

        For the `videos` table:
            - Discovers all videos for a channel via uploads playlist
            - Fetches full video metadata for all discovered videos

        Optional table_options for `videos`:
            - channel_id: The channel ID to fetch videos from. Defaults to
              authenticated user's channel if not provided.
        """
        if table_name not in self.list_tables():
            raise ValueError(f"Unsupported table: {table_name!r}")

        if table_name == "comments":
            return self._read_comments(start_offset, table_options)
        if table_name == "videos":
            return self._read_videos(start_offset, table_options)

        raise ValueError(f"Unsupported table: {table_name!r}")

    def _read_comments(
        self, start_offset: dict, table_options: dict[str, str]
    ) -> (Iterator[dict], dict):
        """
        Internal implementation for reading the `comments` table.

        If video_id is provided, fetches all comments for that specific video.
        If video_id is NOT provided, discovers all videos for the channel
        (using channel_id or authenticated user's channel) and fetches
        comments for all of them.
        """
        video_id = table_options.get("video_id")

        # Determine which videos to fetch comments for
        if video_id:
            # Single video mode
            video_ids = [video_id]
        else:
            # Channel-wide mode: discover all videos
            channel_id = table_options.get("channel_id") or None
            uploads_playlist_id = self._get_uploads_playlist_id(channel_id)
            video_ids = self._enumerate_video_ids_from_playlist(uploads_playlist_id)

        if not video_ids:
            return iter([]), {}

        # Parse options
        try:
            max_results = int(table_options.get("max_results", 100))
        except (TypeError, ValueError):
            max_results = 100
        max_results = max(1, min(max_results, 100))

        text_format = table_options.get("text_format", "plainText")
        if text_format not in ("plainText", "html"):
            text_format = "plainText"

        records: list[dict[str, Any]] = []
        max_updated_at: str | None = None

        # Fetch comments for each video
        for vid in video_ids:
            # Fetch all comment threads for this video
            # (returns empty list if comments are disabled)
            threads = self._fetch_all_comment_threads(vid, max_results, text_format)

            for thread in threads:
                thread_snippet = thread.get("snippet", {})
                top_level_comment = thread_snippet.get("topLevelComment", {})
                top_comment_snippet = top_level_comment.get("snippet", {})

                # Thread-level metadata (inherited by replies too)
                thread_video_id = thread_snippet.get("videoId", vid)
                can_reply = thread_snippet.get("canReply")
                is_public = thread_snippet.get("isPublic")
                total_reply_count = thread_snippet.get("totalReplyCount", 0)

                # Build top-level comment record
                top_record = self._build_comment_record(
                    comment=top_level_comment,
                    comment_snippet=top_comment_snippet,
                    video_id=thread_video_id,
                    can_reply=can_reply,
                    is_public=is_public,
                    total_reply_count=total_reply_count,
                    parent_id=None,
                )
                records.append(top_record)

                # Track max updated_at
                updated_at = top_record.get("updated_at")
                if isinstance(updated_at, str):
                    if max_updated_at is None or updated_at > max_updated_at:
                        max_updated_at = updated_at

                # Step 2: Fetch all replies if there are any
                if total_reply_count and total_reply_count > 0:
                    top_comment_id = top_level_comment.get("id")
                    if top_comment_id:
                        replies = self._fetch_all_replies(
                            top_comment_id, max_results, text_format
                        )

                        for reply in replies:
                            reply_snippet = reply.get("snippet", {})

                            # Build reply record (inherit thread metadata)
                            reply_record = self._build_comment_record(
                                comment=reply,
                                comment_snippet=reply_snippet,
                                video_id=thread_video_id,
                                can_reply=can_reply,
                                is_public=is_public,
                                total_reply_count=0,  # Replies don't have nested replies
                                parent_id=top_comment_id,
                            )
                            records.append(reply_record)

                            # Track max updated_at
                            reply_updated_at = reply_record.get("updated_at")
                            if isinstance(reply_updated_at, str):
                                if max_updated_at is None or reply_updated_at > max_updated_at:
                                    max_updated_at = reply_updated_at

        # Build offset
        next_cursor = None
        if max_updated_at:
            next_cursor = max_updated_at

        if not records and start_offset:
            next_offset = start_offset
        else:
            next_offset = {"cursor": next_cursor} if next_cursor else {}

        return iter(records), next_offset

    def _build_comment_record(
        self,
        comment: dict,
        comment_snippet: dict,
        video_id: str,
        can_reply: bool | None,
        is_public: bool | None,
        total_reply_count: int,
        parent_id: str | None,
    ) -> dict[str, Any]:
        """Build a flattened comment record from API response data."""
        # Extract author_channel_id from nested object
        author_channel_id_obj = comment_snippet.get("authorChannelId")
        author_channel_id = None
        if isinstance(author_channel_id_obj, dict):
            author_channel_id = author_channel_id_obj.get("value")

        return {
            "id": comment.get("id"),
            "video_id": video_id,
            "can_reply": can_reply,
            "is_public": is_public,
            "total_reply_count": total_reply_count,
            "channel_id": comment_snippet.get("channelId"),
            "etag": comment.get("etag"),
            "kind": comment.get("kind"),
            "author_display_name": comment_snippet.get("authorDisplayName"),
            "author_profile_image_url": comment_snippet.get("authorProfileImageUrl"),
            "author_channel_url": comment_snippet.get("authorChannelUrl"),
            "author_channel_id": author_channel_id,
            "text_display": comment_snippet.get("textDisplay"),
            "text_original": comment_snippet.get("textOriginal"),
            "parent_id": parent_id,
            "can_rate": comment_snippet.get("canRate"),
            "viewer_rating": comment_snippet.get("viewerRating"),
            "like_count": comment_snippet.get("likeCount"),
            "moderation_status": comment_snippet.get("moderationStatus"),
            "published_at": comment_snippet.get("publishedAt"),
            "updated_at": comment_snippet.get("updatedAt"),
        }

    def _fetch_all_comment_threads(
        self, video_id: str, max_results: int, text_format: str
    ) -> list[dict]:
        """
        Fetch all comment threads for a video using pagination.

        Returns a list of commentThread resources.
        """
        url = f"{self.BASE_URL}/commentThreads"
        params = {
            "part": "snippet",
            "videoId": video_id,
            "maxResults": max_results,
            "textFormat": text_format,
            "order": "time",
        }

        all_threads: list[dict] = []
        page_token: str | None = None

        while True:
            if page_token:
                params["pageToken"] = page_token

            response = self._session.get(
                url, params=params, headers=self._get_headers(), timeout=30
            )

            # Handle specific error cases
            if response.status_code == 403:
                error_data = response.json() if response.text else {}
                errors = error_data.get("error", {}).get("errors", [])
                for err in errors:
                    if err.get("reason") == "commentsDisabled":
                        # Comments are disabled for this video - return empty
                        return []
                raise RuntimeError(
                    f"YouTube API error (403): {response.text}"
                )

            if response.status_code == 404:
                # Video not found
                raise ValueError(
                    f"Video not found: {video_id}"
                )

            if response.status_code != 200:
                raise RuntimeError(
                    f"YouTube API error for commentThreads: {response.status_code} {response.text}"
                )

            data = response.json()
            items = data.get("items", [])
            all_threads.extend(items)

            page_token = data.get("nextPageToken")
            if not page_token:
                break

        return all_threads

    def _fetch_all_replies(
        self, parent_id: str, max_results: int, text_format: str
    ) -> list[dict]:
        """
        Fetch all replies for a comment using pagination.

        Returns a list of comment resources (replies).
        """
        url = f"{self.BASE_URL}/comments"
        params = {
            "part": "snippet",
            "parentId": parent_id,
            "maxResults": max_results,
            "textFormat": text_format,
        }

        all_replies: list[dict] = []
        page_token: str | None = None

        while True:
            if page_token:
                params["pageToken"] = page_token

            response = self._session.get(
                url, params=params, headers=self._get_headers(), timeout=30
            )

            if response.status_code != 200:
                raise RuntimeError(
                    f"YouTube API error for comments (replies): {response.status_code} {response.text}"
                )

            data = response.json()
            items = data.get("items", [])
            all_replies.extend(items)

            page_token = data.get("nextPageToken")
            if not page_token:
                break

        return all_replies

    # -------------------------------------------------------------------------
    # Videos table implementation
    # -------------------------------------------------------------------------

    def _read_videos(
        self, start_offset: dict, table_options: dict[str, str]
    ) -> (Iterator[dict], dict):
        """
        Internal implementation for reading the `videos` table.

        Discovers all videos for a channel via uploads playlist, then fetches
        full video metadata.
        """
        channel_id = table_options.get("channel_id") or None

        # Step 1: Get uploads playlist ID
        uploads_playlist_id = self._get_uploads_playlist_id(channel_id)

        # Step 2: Enumerate all video IDs from uploads playlist
        video_ids = self._enumerate_video_ids_from_playlist(uploads_playlist_id)

        if not video_ids:
            return iter([]), {}

        # Step 3: Fetch video metadata in batches of 50
        all_videos = self._fetch_videos_metadata(video_ids)

        # Build flattened records
        records: list[dict[str, Any]] = []
        for video in all_videos:
            record = self._build_video_record(video)
            records.append(record)

        # Snapshot ingestion - no cursor needed
        return iter(records), {}

    def _get_uploads_playlist_id(self, channel_id: str | None) -> str:
        """
        Get the uploads playlist ID for a channel.

        If channel_id is None, uses the authenticated user's channel (mine=true).
        """
        url = f"{self.BASE_URL}/channels"
        params: dict[str, Any] = {"part": "contentDetails"}

        if channel_id:
            params["id"] = channel_id
        else:
            params["mine"] = "true"

        response = self._session.get(
            url, params=params, headers=self._get_headers(), timeout=30
        )

        if response.status_code != 200:
            raise RuntimeError(
                f"YouTube API error for channels: {response.status_code} {response.text}"
            )

        data = response.json()
        items = data.get("items", [])

        if not items:
            if channel_id:
                raise ValueError(f"Channel not found: {channel_id}")
            raise ValueError(
                "No channel found for authenticated user. "
                "Ensure the OAuth token has access to a YouTube channel."
            )

        content_details = items[0].get("contentDetails", {})
        related_playlists = content_details.get("relatedPlaylists", {})
        uploads_playlist_id = related_playlists.get("uploads")

        if not uploads_playlist_id:
            raise ValueError(
                f"No uploads playlist found for channel. "
                f"Channel may not have any uploaded videos."
            )

        return uploads_playlist_id

    def _enumerate_video_ids_from_playlist(self, playlist_id: str) -> list[str]:
        """
        Enumerate all video IDs from a playlist using pagination.

        Returns a list of video IDs.
        """
        url = f"{self.BASE_URL}/playlistItems"
        params = {
            "part": "contentDetails",
            "playlistId": playlist_id,
            "maxResults": 50,
        }

        video_ids: list[str] = []
        page_token: str | None = None

        while True:
            if page_token:
                params["pageToken"] = page_token

            response = self._session.get(
                url, params=params, headers=self._get_headers(), timeout=30
            )

            if response.status_code != 200:
                raise RuntimeError(
                    f"YouTube API error for playlistItems: "
                    f"{response.status_code} {response.text}"
                )

            data = response.json()
            items = data.get("items", [])

            for item in items:
                content_details = item.get("contentDetails", {})
                video_id = content_details.get("videoId")
                if video_id:
                    video_ids.append(video_id)

            page_token = data.get("nextPageToken")
            if not page_token:
                break

        return video_ids

    def _fetch_videos_metadata(self, video_ids: list[str]) -> list[dict]:
        """
        Fetch full video metadata for a list of video IDs.

        Batches requests in groups of 50 (YouTube API limit).
        """
        url = f"{self.BASE_URL}/videos"
        parts = (
            "snippet,contentDetails,statistics,status,player,"
            "topicDetails,recordingDetails,liveStreamingDetails"
        )

        all_videos: list[dict] = []

        # Process in batches of 50
        for i in range(0, len(video_ids), 50):
            batch = video_ids[i : i + 50]
            params = {
                "part": parts,
                "id": ",".join(batch),
            }

            response = self._session.get(
                url, params=params, headers=self._get_headers(), timeout=30
            )

            if response.status_code != 200:
                raise RuntimeError(
                    f"YouTube API error for videos: "
                    f"{response.status_code} {response.text}"
                )

            data = response.json()
            items = data.get("items", [])
            all_videos.extend(items)

        return all_videos

    def _build_video_record(self, video: dict) -> dict[str, Any]:
        """Build a flattened video record from API response data."""
        snippet = video.get("snippet", {})
        content_details = video.get("contentDetails", {})
        statistics = video.get("statistics", {})
        status = video.get("status", {})
        player = video.get("player", {})
        topic_details = video.get("topicDetails", {})
        recording_details = video.get("recordingDetails", {})
        live_streaming = video.get("liveStreamingDetails", {})
        paid_placement = video.get("paidProductPlacementDetails", {})

        # Extract localized fields
        localized = snippet.get("localized", {})

        # Extract best thumbnail URL (prefer maxres > high > medium > default)
        thumbnails = snippet.get("thumbnails", {})
        thumbnail_url = None
        for quality in ["maxres", "high", "medium", "default"]:
            if quality in thumbnails and thumbnails[quality].get("url"):
                thumbnail_url = thumbnails[quality]["url"]
                break

        # Extract region restriction
        region_restriction = content_details.get("regionRestriction", {})

        # Extract content rating
        content_rating = content_details.get("contentRating", {})

        # Helper to safely parse integer stats (YouTube returns them as strings)
        def safe_long(value: Any) -> int | None:
            if value is None:
                return None
            try:
                return int(value)
            except (ValueError, TypeError):
                return None

        return {
            # Core fields
            "id": video.get("id"),
            "etag": video.get("etag"),
            "kind": video.get("kind"),
            # Snippet fields
            "published_at": snippet.get("publishedAt"),
            "channel_id": snippet.get("channelId"),
            "title": snippet.get("title"),
            "description": snippet.get("description"),
            "channel_title": snippet.get("channelTitle"),
            "tags": snippet.get("tags"),
            "category_id": snippet.get("categoryId"),
            "live_broadcast_content": snippet.get("liveBroadcastContent"),
            "default_language": snippet.get("defaultLanguage"),
            "default_audio_language": snippet.get("defaultAudioLanguage"),
            "localized_title": localized.get("title"),
            "localized_description": localized.get("description"),
            "thumbnail_url": thumbnail_url,
            # Content details
            "content_details_duration": content_details.get("duration"),
            "content_details_dimension": content_details.get("dimension"),
            "content_details_definition": content_details.get("definition"),
            "content_details_caption": content_details.get("caption"),
            "content_details_licensed_content": content_details.get("licensedContent"),
            "content_details_projection": content_details.get("projection"),
            "content_details_has_custom_thumbnail": content_details.get(
                "hasCustomThumbnail"
            ),
            "content_details_region_restriction_allowed": region_restriction.get(
                "allowed"
            ),
            "content_details_region_restriction_blocked": region_restriction.get(
                "blocked"
            ),
            "content_details_content_rating_mpaa": content_rating.get("mpaaRating"),
            "content_details_content_rating_yt": content_rating.get("ytRating"),
            # Status
            "status_upload_status": status.get("uploadStatus"),
            "status_failure_reason": status.get("failureReason"),
            "status_rejection_reason": status.get("rejectionReason"),
            "status_privacy_status": status.get("privacyStatus"),
            "status_publish_at": status.get("publishAt"),
            "status_license": status.get("license"),
            "status_embeddable": status.get("embeddable"),
            "status_public_stats_viewable": status.get("publicStatsViewable"),
            "status_made_for_kids": status.get("madeForKids"),
            "status_self_declared_made_for_kids": status.get("selfDeclaredMadeForKids"),
            "status_contains_synthetic_media": status.get("containsSyntheticMedia"),
            # Statistics (convert string counts to integers)
            "statistics_view_count": safe_long(statistics.get("viewCount")),
            "statistics_like_count": safe_long(statistics.get("likeCount")),
            "statistics_favorite_count": safe_long(statistics.get("favoriteCount")),
            "statistics_comment_count": safe_long(statistics.get("commentCount")),
            # Player
            "player_embed_html": player.get("embedHtml"),
            # Topic details
            "topic_details_topic_ids": topic_details.get("topicIds"),
            "topic_details_relevant_topic_ids": topic_details.get("relevantTopicIds"),
            "topic_details_topic_categories": topic_details.get("topicCategories"),
            # Recording details
            "recording_details_recording_date": recording_details.get("recordingDate"),
            # Paid product placement
            "paid_product_placement_details_has_paid_product_placement": paid_placement.get(
                "hasPaidProductPlacement"
            ),
            # Live streaming details
            "live_streaming_details_actual_start_time": live_streaming.get(
                "actualStartTime"
            ),
            "live_streaming_details_actual_end_time": live_streaming.get(
                "actualEndTime"
            ),
            "live_streaming_details_scheduled_start_time": live_streaming.get(
                "scheduledStartTime"
            ),
            "live_streaming_details_scheduled_end_time": live_streaming.get(
                "scheduledEndTime"
            ),
            "live_streaming_details_concurrent_viewers": safe_long(
                live_streaming.get("concurrentViewers")
            ),
            "live_streaming_details_active_chat_id": live_streaming.get(
                "activeLiveChatId"
            ),
        }
