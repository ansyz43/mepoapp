"""
Token Manager — periodically refreshes long-lived Meta access tokens.

Checks channels whose tokens expire within 7 days and refreshes them.
"""
import asyncio
import datetime
import logging

import httpx

from meta_worker.config import settings
from meta_worker.database import async_session
from meta_worker.models import Channel
from meta_worker.crypto import decrypt_token
from sqlalchemy import select

logger = logging.getLogger(__name__)

BASE_URL = f"https://graph.facebook.com/{settings.META_API_VERSION}"
REFRESH_BEFORE_DAYS = 7
CHECK_INTERVAL_HOURS = 6


async def refresh_token(access_token: str) -> dict | None:
    """Exchange a long-lived token for a new one."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            f"{BASE_URL}/oauth/access_token",
            params={
                "grant_type": "fb_exchange_token",
                "client_id": settings.META_APP_ID,
                "client_secret": settings.META_APP_SECRET,
                "fb_exchange_token": access_token,
            },
        )
        data = resp.json()
        if "error" in data:
            logger.error(f"Token refresh failed: {data['error'].get('message')}")
            return None
        expires_in = data.get("expires_in", 5184000)
        return {
            "access_token": data["access_token"],
            "expires_at": datetime.datetime.now(datetime.UTC) + datetime.timedelta(seconds=expires_in),
        }


async def refresh_expiring_tokens():
    """Check all channels and refresh tokens expiring within REFRESH_BEFORE_DAYS."""
    from meta_worker.crypto import decrypt_token
    import base64, hashlib
    from cryptography.fernet import Fernet

    def _encrypt(token: str) -> str:
        key = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
        f = Fernet(base64.urlsafe_b64encode(key))
        return f.encrypt(token.encode()).decode()

    cutoff = datetime.datetime.now(datetime.UTC) + datetime.timedelta(days=REFRESH_BEFORE_DAYS)

    async with async_session() as db:
        result = await db.execute(
            select(Channel).where(
                Channel.is_active == True,
                Channel.token_expires_at.isnot(None),
                Channel.token_expires_at <= cutoff,
            )
        )
        channels = result.scalars().all()

        for ch in channels:
            try:
                current_token = decrypt_token(ch.access_token_encrypted)
                new_data = await refresh_token(current_token)
                if new_data:
                    ch.access_token_encrypted = _encrypt(new_data["access_token"])
                    ch.token_expires_at = new_data["expires_at"]
                    logger.info(f"Refreshed token for channel {ch.id} ({ch.channel_name})")
                else:
                    logger.warning(f"Failed to refresh token for channel {ch.id}")
            except Exception as e:
                logger.error(f"Error refreshing channel {ch.id}: {e}")

        await db.commit()


async def token_refresh_loop():
    """Background loop that periodically refreshes tokens."""
    while True:
        try:
            await refresh_expiring_tokens()
        except Exception as e:
            logger.error(f"Token refresh loop error: {e}", exc_info=True)
        await asyncio.sleep(CHECK_INTERVAL_HOURS * 3600)
