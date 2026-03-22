"""
Meta Graph API client for the worker process.

Handles: Send API, user profile lookup.
"""
import logging

import httpx

from meta_worker.config import settings

logger = logging.getLogger(__name__)

BASE_URL = f"https://graph.facebook.com/{settings.META_API_VERSION}"


class MetaAPI:
    """Async Meta Graph API client for message sending."""

    def __init__(self):
        self._http = httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=10.0))

    async def close(self):
        await self._http.aclose()

    async def send_message(
        self,
        access_token: str,
        recipient_id: str,
        text: str,
    ) -> bool:
        """Send a text message via Meta Send API."""
        resp = await self._http.post(
            f"{BASE_URL}/me/messages",
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
