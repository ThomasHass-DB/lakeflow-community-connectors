# pylint: disable=too-many-lines
"""YouTube Analytics connector using YouTube Data API v3."""

import json
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
    TimestampType,
)


class LakeflowConnect:
    """
    YouTube Data API v3 connector for fetching captions, channels, comments, and videos.

    This connector uses OAuth 2.0 with refresh token authentication.
    The UC connection must provide: client_id, client_secret, refresh_token.

    Supported tables:
        - captions: Caption track content (one row per cue). Downloads and parses
          caption files. NOTE: Only works for videos owned by authenticated user.
        - channels: Channel metadata. Optionally accepts channel_id (defaults to
          authenticated user's channel).
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
        return ["captions", "channels", "comments", "videos"]

    def _get_captions_schema(self) -> StructType:
        """Return the captions table schema (one row per caption cue)."""
        return StructType(
            [
                # Composite primary key
                StructField("id", StringType(), False),  # Caption track ID
                StructField("start_ms", LongType(), False),  # Cue start time in ms
                # Video reference
                StructField("video_id", StringType(), False),
                # Parsed content
                StructField("end_ms", LongType(), True),
                StructField("duration_ms", LongType(), True),
                StructField("text", StringType(), True),
                # Track metadata
                StructField("language", StringType(), True),
                StructField("name", StringType(), True),
                StructField("track_kind", StringType(), True),
                StructField("audio_track_type", StringType(), True),
                StructField("is_cc", BooleanType(), True),
                StructField("is_large", BooleanType(), True),
                StructField("is_easy_reader", BooleanType(), True),
                StructField("is_draft", BooleanType(), True),
                StructField("is_auto_synced", BooleanType(), True),
                StructField("status", StringType(), True),
                StructField("failure_reason", StringType(), True),
                StructField("last_updated", TimestampType(), True),
                StructField("etag", StringType(), True),
                StructField("kind", StringType(), True),
            ]
        )

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
                StructField("published_at", TimestampType(), True),
                StructField("updated_at", TimestampType(), True),
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
                StructField("published_at", TimestampType(), True),
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
                StructField("status_publish_at", TimestampType(), True),
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
                StructField("recording_details_recording_date", TimestampType(), True),
                # Paid product placement
                StructField(
                    "paid_product_placement_details_has_paid_product_placement",
                    BooleanType(),
                    True,
                ),
                # Live streaming details
                StructField(
                    "live_streaming_details_actual_start_time", TimestampType(), True
                ),
                StructField(
                    "live_streaming_details_actual_end_time", TimestampType(), True
                ),
                StructField(
                    "live_streaming_details_scheduled_start_time", TimestampType(), True
                ),
                StructField(
                    "live_streaming_details_scheduled_end_time", TimestampType(), True
                ),
                StructField(
                    "live_streaming_details_concurrent_viewers", LongType(), True
                ),
                StructField(
                    "live_streaming_details_active_chat_id", StringType(), True
                ),
            ]
        )

    def _get_channels_schema(self) -> StructType:
        """Return the channels table schema with mixed flattening approach."""
        return StructType(
            [
                # Primary key and core fields
                StructField("id", StringType(), False),
                StructField("etag", StringType(), True),
                StructField("kind", StringType(), True),
                # Snippet fields (flattened)
                StructField("title", StringType(), True),
                StructField("description", StringType(), True),
                StructField("custom_url", StringType(), True),
                StructField("published_at", TimestampType(), True),
                StructField("country", StringType(), True),
                StructField("thumbnail_url", StringType(), True),
                StructField("default_language", StringType(), True),
                StructField("localized_title", StringType(), True),
                StructField("localized_description", StringType(), True),
                # Statistics (flattened)
                StructField("total_view_count", LongType(), True),
                StructField("total_subscriber_count", LongType(), True),
                StructField("total_video_count", LongType(), True),
                StructField("hidden_subscriber_count", BooleanType(), True),
                # Content details (flattened)
                StructField("uploads_playlist_id", StringType(), True),
                StructField("likes_playlist_id", StringType(), True),
                # Branding settings (flattened keyword only)
                StructField("keywords", StringType(), True),
                # Topic details (array)
                StructField("topic_categories", ArrayType(StringType()), True),
                # Nested objects stored as JSON strings
                StructField("status", StringType(), True),
                StructField("branding_settings", StringType(), True),
                StructField("localizations", StringType(), True),
                # Content owner details (flattened - YouTube Partners only)
                StructField("content_owner_id", StringType(), True),
                StructField("content_owner_time_linked", TimestampType(), True),
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

        if table_name == "captions":
            return self._get_captions_schema()
        if table_name == "channels":
            return self._get_channels_schema()
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

        For `channels`:
            - ingestion_type: snapshot
            - primary_keys: ["id"]

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

        if table_name == "captions":
            return {
                "primary_keys": ["id", "start_ms"],
                "ingestion_type": "snapshot",
            }
        if table_name == "channels":
            return {
                "primary_keys": ["id"],
                "ingestion_type": "snapshot",
            }
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

        For the `captions` table:
            - Downloads and parses caption content for videos.
            - Creates one row per caption cue (subtitle line).
            - NOTE: Caption download only works for videos owned by the
              authenticated user.

        Optional table_options for `captions`:
            - video_id: The video ID to fetch captions for. If not provided,
              discovers all videos for the channel.
            - channel_id: The channel ID (used when video_id is not provided).

        For the `channels` table:
            - Fetches channel metadata

        Optional table_options for `channels`:
            - channel_id: The channel ID to fetch. Defaults to authenticated
              user's channel if not provided.

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

        if table_name == "captions":
            return self._read_captions(start_offset, table_options)
        if table_name == "channels":
            return self._read_channels(start_offset, table_options)
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

    # -------------------------------------------------------------------------
    # Captions table implementation
    # -------------------------------------------------------------------------

    def _read_captions(
        self, start_offset: dict, table_options: dict[str, str]
    ) -> (Iterator[dict], dict):
        """
        Internal implementation for reading the `captions` table.

        Downloads and parses caption content for videos owned by the
        authenticated user. Creates one row per caption cue.

        NOTE: Caption download only works for videos you own.
        """
        import re

        video_id = table_options.get("video_id")

        # Determine which videos to fetch captions for
        if video_id:
            video_ids = [video_id]
        else:
            # Discover all videos for the channel
            channel_id = table_options.get("channel_id") or None
            uploads_playlist_id = self._get_uploads_playlist_id(channel_id)
            if not uploads_playlist_id:
                return iter([]), {}
            video_ids = list(self._enumerate_video_ids_from_playlist(uploads_playlist_id))
            if not video_ids:
                return iter([]), {}

        def generate_caption_records():
            for vid_id in video_ids:
                # Fetch caption tracks for this video
                caption_tracks = self._fetch_caption_tracks(vid_id)

                for track in caption_tracks:
                    track_id = track.get("id")
                    snippet = track.get("snippet", {})
                    status = snippet.get("status", "")

                    # Skip tracks that aren't serving
                    if status != "serving":
                        continue

                    # Download caption content in SRT format
                    srt_content = self._download_caption(track_id)
                    if not srt_content:
                        continue

                    # Parse SRT into cues
                    cues = self._parse_srt(srt_content, re)

                    # Build records for each cue
                    for cue in cues:
                        yield self._build_caption_record(track, vid_id, cue)

        return generate_caption_records(), {}

    def _fetch_caption_tracks(self, video_id: str) -> list[dict]:
        """
        Fetch caption track metadata for a video.

        Returns list of caption track resources.
        """
        url = f"{self.BASE_URL}/captions"
        params = {
            "part": "snippet",
            "videoId": video_id,
        }

        response = self._session.get(
            url, headers=self._get_headers(), params=params, timeout=30
        )

        if response.status_code == 403:
            # Forbidden - likely not owner of video or captions disabled
            return []
        if response.status_code == 404:
            # Video not found
            return []
        if response.status_code != 200:
            raise RuntimeError(
                f"captions.list failed: {response.status_code} {response.text}"
            )

        data = response.json()
        return data.get("items", [])

    def _download_caption(self, caption_id: str) -> str | None:
        """
        Download caption content in SRT format.

        Returns the SRT content as string, or None if download fails.
        """
        url = f"{self.BASE_URL}/captions/{caption_id}"
        params = {"tfmt": "srt"}

        response = self._session.get(
            url, headers=self._get_headers(), params=params, timeout=60
        )

        if response.status_code == 403:
            # Forbidden - not owner of video
            return None
        if response.status_code == 404:
            # Caption track not found
            return None
        if response.status_code != 200:
            # Log but don't fail - some tracks may be unavailable
            return None

        return response.text

    def _parse_srt(self, srt_content: str, re_module: Any) -> list[dict]:
        """
        Parse SRT subtitle content into list of cue dictionaries.

        Each cue contains: start_ms, end_ms, duration_ms, text
        """
        cues = []
        # Split by double newline (cue separator)
        # Handle both Unix and Windows line endings
        normalized = srt_content.replace("\r\n", "\n")
        blocks = re_module.split(r"\n\n+", normalized.strip())

        for block in blocks:
            lines = block.strip().split("\n")
            if len(lines) < 2:
                continue

            # First line is cue number (skip)
            # Second line is timestamp: HH:MM:SS,mmm --> HH:MM:SS,mmm
            timestamp_match = re_module.match(
                r"(\d{1,2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*"
                r"(\d{1,2}):(\d{2}):(\d{2}),(\d{3})",
                lines[1],
            )
            if not timestamp_match:
                continue

            # Convert to milliseconds
            start_ms = (
                int(timestamp_match.group(1)) * 3600000
                + int(timestamp_match.group(2)) * 60000
                + int(timestamp_match.group(3)) * 1000
                + int(timestamp_match.group(4))
            )
            end_ms = (
                int(timestamp_match.group(5)) * 3600000
                + int(timestamp_match.group(6)) * 60000
                + int(timestamp_match.group(7)) * 1000
                + int(timestamp_match.group(8))
            )

            # Text is everything after timestamp line
            text = "\n".join(lines[2:]) if len(lines) > 2 else ""

            cues.append(
                {
                    "start_ms": start_ms,
                    "end_ms": end_ms,
                    "duration_ms": end_ms - start_ms,
                    "text": text,
                }
            )

        return cues

    def _build_caption_record(
        self, track: dict, video_id: str, cue: dict
    ) -> dict[str, Any]:
        """
        Build a flattened caption record from track metadata and parsed cue.
        """
        snippet = track.get("snippet", {})

        return {
            # Composite primary key
            "id": track.get("id"),
            "start_ms": cue.get("start_ms"),
            # Video reference
            "video_id": video_id,
            # Parsed content
            "end_ms": cue.get("end_ms"),
            "duration_ms": cue.get("duration_ms"),
            "text": cue.get("text"),
            # Track metadata
            "language": snippet.get("language"),
            "name": snippet.get("name"),
            "track_kind": snippet.get("trackKind"),
            "audio_track_type": snippet.get("audioTrackType"),
            "is_cc": snippet.get("isCC"),
            "is_large": snippet.get("isLarge"),
            "is_easy_reader": snippet.get("isEasyReader"),
            "is_draft": snippet.get("isDraft"),
            "is_auto_synced": snippet.get("isAutoSynced"),
            "status": snippet.get("status"),
            "failure_reason": snippet.get("failureReason"),
            "last_updated": snippet.get("lastUpdated"),
            "etag": track.get("etag"),
            "kind": track.get("kind"),
        }

    # -------------------------------------------------------------------------
    # Channels table implementation
    # -------------------------------------------------------------------------

    def _read_channels(
        self, start_offset: dict, table_options: dict[str, str]
    ) -> (Iterator[dict], dict):
        """
        Internal implementation for reading the `channels` table.

        Fetches channel metadata for the authenticated user's channel or a
        specified channel ID.
        """
        channel_id = table_options.get("channel_id") or None

        # Fetch channel metadata
        channel = self._fetch_channel_metadata(channel_id)

        if not channel:
            return iter([]), {}

        # Build flattened record
        record = self._build_channel_record(channel)

        # Snapshot ingestion - no cursor needed
        return iter([record]), {}

    def _fetch_channel_metadata(self, channel_id: str | None) -> dict | None:
        """
        Fetch channel metadata from the YouTube API.

        If channel_id is None, uses the authenticated user's channel (mine=true).
        """
        url = f"{self.BASE_URL}/channels"
        parts = (
            "snippet,contentDetails,statistics,topicDetails,"
            "status,brandingSettings,localizations,contentOwnerDetails"
        )
        params: dict[str, Any] = {"part": parts}

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

        return items[0]

    def _build_channel_record(self, channel: dict) -> dict[str, Any]:
        """Build a channel record from API response data with mixed flattening."""
        snippet = channel.get("snippet", {})
        content_details = channel.get("contentDetails", {})
        statistics = channel.get("statistics", {})
        topic_details = channel.get("topicDetails", {})
        status = channel.get("status", {})
        branding_settings = channel.get("brandingSettings", {})
        localizations = channel.get("localizations")
        content_owner_details = channel.get("contentOwnerDetails", {})

        # Extract localized fields
        localized = snippet.get("localized", {})

        # Extract thumbnail URL (prefer high > medium > default)
        thumbnails = snippet.get("thumbnails", {})
        thumbnail_url = None
        for quality in ["high", "medium", "default"]:
            if quality in thumbnails and thumbnails[quality].get("url"):
                thumbnail_url = thumbnails[quality]["url"]
                break

        # Extract related playlists
        related_playlists = content_details.get("relatedPlaylists", {})

        # Extract keywords from branding settings
        branding_channel = branding_settings.get("channel", {})
        keywords = branding_channel.get("keywords")

        # Helper to safely parse integer stats (YouTube returns them as strings)
        def safe_long(value: Any) -> int | None:
            if value is None:
                return None
            try:
                return int(value)
            except (ValueError, TypeError):
                return None

        # Helper to serialize objects to JSON strings
        def to_json_string(obj: Any) -> str | None:
            if obj is None or obj == {}:
                return None
            try:
                return json.dumps(obj)
            except (TypeError, ValueError):
                return None

        return {
            # Core fields
            "id": channel.get("id"),
            "etag": channel.get("etag"),
            "kind": channel.get("kind"),
            # Snippet fields (flattened)
            "title": snippet.get("title"),
            "description": snippet.get("description"),
            "custom_url": snippet.get("customUrl"),
            "published_at": snippet.get("publishedAt"),
            "country": snippet.get("country"),
            "thumbnail_url": thumbnail_url,
            "default_language": snippet.get("defaultLanguage"),
            "localized_title": localized.get("title"),
            "localized_description": localized.get("description"),
            # Statistics (flattened, converted to integers)
            "total_view_count": safe_long(statistics.get("viewCount")),
            "total_subscriber_count": safe_long(statistics.get("subscriberCount")),
            "total_video_count": safe_long(statistics.get("videoCount")),
            "hidden_subscriber_count": statistics.get("hiddenSubscriberCount"),
            # Content details (flattened)
            "uploads_playlist_id": related_playlists.get("uploads"),
            "likes_playlist_id": related_playlists.get("likes") or None,
            # Branding settings (keyword only)
            "keywords": keywords,
            # Topic details (array)
            "topic_categories": topic_details.get("topicCategories"),
            # Nested objects as JSON strings
            "status": to_json_string(status),
            "branding_settings": to_json_string(branding_settings),
            "localizations": to_json_string(localizations),
            # Content owner details (flattened - YouTube Partners only)
            "content_owner_id": content_owner_details.get("contentOwner"),
            "content_owner_time_linked": content_owner_details.get("timeLinked"),
        }
