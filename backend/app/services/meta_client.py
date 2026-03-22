"""
Meta Graph API client for Instagram Messaging and Facebook Messenger.

Handles: OAuth token exchange, long-lived tokens, page/IG info,
webhook subscriptions, Send API, user profile lookup.
"""
import logging
import datetime

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

BASE_URL = f"https://graph.facebook.com/{settings.META_API_VERSION}"


class MetaClientError(Exception):
    """Meta API error with status and message."""
    def __init__(self, message: str, status_code: int = 0):
        self.status_code = status_code
        super().__init__(message)


class MetaClient:
    """Async Meta Graph API client."""

    def __init__(self):
        self._http = httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=10.0))

    async def close(self):
        await self._http.aclose()

    # ─── OAuth ───

    async def exchange_code_for_token(self, code: str, redirect_uri: str) -> dict:
        """Exchange short-lived code for access token."""
        resp = await self._http.get(
            f"{BASE_URL}/oauth/access_token",
            params={
                "client_id": settings.META_APP_ID,
                "client_secret": settings.META_APP_SECRET,
                "redirect_uri": redirect_uri,
                "code": code,
            },
        )
        data = resp.json()
        if "error" in data:
            raise MetaClientError(data["error"].get("message", "OAuth failed"), resp.status_code)
        return data  # {"access_token": "...", "token_type": "bearer"}

    async def get_long_lived_token(self, short_token: str) -> dict:
        """Exchange short-lived token for a 60-day long-lived token."""
        resp = await self._http.get(
            f"{BASE_URL}/oauth/access_token",
            params={
                "grant_type": "fb_exchange_token",
                "client_id": settings.META_APP_ID,
                "client_secret": settings.META_APP_SECRET,
                "fb_exchange_token": short_token,
            },
        )
        data = resp.json()
        if "error" in data:
            raise MetaClientError(data["error"].get("message", "Token exchange failed"))
        expires_in = data.get("expires_in", 5184000)  # default 60 days
        return {
            "access_token": data["access_token"],
            "expires_at": datetime.datetime.now(datetime.UTC) + datetime.timedelta(seconds=expires_in),
        }

    async def refresh_long_lived_token(self, token: str) -> dict:
        """Refresh a long-lived token (valid within last 60 days)."""
        resp = await self._http.get(
            f"{BASE_URL}/oauth/access_token",
            params={
                "grant_type": "fb_exchange_token",
                "client_id": settings.META_APP_ID,
                "client_secret": settings.META_APP_SECRET,
                "fb_exchange_token": token,
            },
        )
        data = resp.json()
        if "error" in data:
            raise MetaClientError(data["error"].get("message", "Refresh failed"))
        expires_in = data.get("expires_in", 5184000)
        return {
            "access_token": data["access_token"],
            "expires_at": datetime.datetime.now(datetime.UTC) + datetime.timedelta(seconds=expires_in),
        }

    # ─── Page & IG Info ───

    async def get_pages(self, user_token: str) -> list[dict]:
        """Get pages managed by this user."""
        resp = await self._http.get(
            f"{BASE_URL}/me/accounts",
            params={"access_token": user_token, "fields": "id,name,access_token,instagram_business_account"},
        )
        data = resp.json()
        if "error" in data:
            raise MetaClientError(data["error"].get("message", "Failed to get pages"))
        return data.get("data", [])

    async def get_instagram_account(self, page_id: str, page_token: str) -> dict | None:
        """Get the Instagram Business account linked to a page."""
        resp = await self._http.get(
            f"{BASE_URL}/{page_id}",
            params={"access_token": page_token, "fields": "instagram_business_account{id,username,profile_picture_url}"},
        )
        data = resp.json()
        ig = data.get("instagram_business_account")
        return ig

    async def get_page_info(self, page_id: str, page_token: str) -> dict:
        """Get page name and info."""
        resp = await self._http.get(
            f"{BASE_URL}/{page_id}",
            params={"access_token": page_token, "fields": "id,name,picture"},
        )
        return resp.json()

    # ─── Webhook Subscriptions ───

    async def subscribe_page_webhooks(self, page_id: str, page_token: str) -> bool:
        """Subscribe page to messaging webhooks."""
        resp = await self._http.post(
            f"{BASE_URL}/{page_id}/subscribed_apps",
            params={"access_token": page_token},
            json={"subscribed_fields": ["messages", "messaging_postbacks", "messaging_referrals"]},
        )
        data = resp.json()
        if data.get("success"):
            logger.info(f"Webhook subscription active for page {page_id}")
            return True
        logger.error(f"Webhook subscription failed for page {page_id}: {data}")
        return False

    # ─── Send API ───

    async def send_message(
        self,
        access_token: str,
        recipient_id: str,
        text: str,
        platform: str = "instagram",
    ) -> bool:
        """Send a text message via Meta Send API."""
        if platform == "instagram":
            url = f"{BASE_URL}/me/messages"
        else:
            url = f"{BASE_URL}/me/messages"

        resp = await self._http.post(
            url,
            params={"access_token": access_token},
            json={
                "recipient": {"id": recipient_id},
                "message": {"text": text},
            },
        )
        data = resp.json()
        if "error" in data:
            err = data["error"]
            logger.warning(f"Send failed to {recipient_id}: {err.get('message')} (code={err.get('code')})")
            return False
        return True

    async def send_image(
        self,
        access_token: str,
        recipient_id: str,
        image_url: str,
    ) -> bool:
        """Send an image message."""
        resp = await self._http.post(
            f"{BASE_URL}/me/messages",
            params={"access_token": access_token},
            json={
                "recipient": {"id": recipient_id},
                "message": {
                    "attachment": {
                        "type": "image",
                        "payload": {"url": image_url, "is_reusable": True},
                    }
                },
            },
        )
        data = resp.json()
        return "error" not in data

    # ─── User Profile ───

    async def get_user_profile(self, user_id: str, access_token: str) -> dict:
        """Get user profile (name, profile_pic)."""
        resp = await self._http.get(
            f"{BASE_URL}/{user_id}",
            params={"access_token": access_token, "fields": "name,profile_pic"},
        )
        data = resp.json()
        if "error" in data:
            return {}
        return data
