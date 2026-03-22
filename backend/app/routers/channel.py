import logging
import time
from pathlib import Path
from io import BytesIO

from PIL import Image
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import User, Channel
from app.schemas import (
    ChannelConnectRequest, ChannelUpdateRequest,
    ChannelResponse, ChannelStatusResponse,
)
from app.auth import get_current_user
from app.config import settings
from app.services.crypto import encrypt_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/channel", tags=["channel"])


async def _load_user_channels(user: User, db: AsyncSession) -> User:
    result = await db.execute(
        select(User).options(selectinload(User.channels)).where(User.id == user.id)
    )
    return result.scalar_one()


def _get_channel_by_platform(user: User, platform: str) -> Channel | None:
    for ch in user.channels:
        if ch.platform == platform:
            return ch
    return None


def _channel_response(ch: Channel) -> ChannelResponse:
    return ChannelResponse(
        id=ch.id,
        platform=ch.platform,
        channel_name=ch.channel_name,
        assistant_name=ch.assistant_name,
        seller_link=ch.seller_link,
        greeting_message=ch.greeting_message,
        bot_description=ch.bot_description,
        avatar_url=ch.avatar_url,
        allow_partners=ch.allow_partners,
        is_active=ch.is_active,
        webhook_status=ch.webhook_status,
        created_at=ch.created_at,
    )


# ── Instagram endpoints ──

@router.post("/instagram/connect", response_model=ChannelResponse, status_code=201)
async def connect_instagram(
    data: ChannelConnectRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Connect Instagram Business Account via OAuth code exchange."""
    user = await _load_user_channels(user, db)
    if _get_channel_by_platform(user, "instagram"):
        raise HTTPException(status_code=400, detail="You already have an Instagram channel connected")

    from app.services.meta_client import MetaClient
    meta = MetaClient()

    # Exchange code for token
    token_data = await meta.exchange_code_for_token(data.code)
    short_token = token_data.get("access_token")
    if not short_token:
        raise HTTPException(status_code=400, detail="Failed to exchange authorization code")

    # Get long-lived token
    long_token_data = await meta.get_long_lived_token(short_token)
    access_token = long_token_data.get("access_token", short_token)

    # Get Instagram account info
    ig_info = await meta.get_ig_account_info(access_token)
    if not ig_info:
        raise HTTPException(status_code=400, detail="Could not retrieve Instagram account info")

    # Subscribe to webhooks
    page_id = ig_info.get("page_id", "")
    if page_id:
        await meta.subscribe_webhook(access_token, page_id)

    channel = Channel(
        user_id=user.id,
        platform="instagram",
        channel_name=ig_info.get("username", "Instagram"),
        meta_page_id=page_id,
        meta_ig_account_id=ig_info.get("ig_account_id", ""),
        access_token_encrypted=encrypt_token(access_token),
        webhook_status="active",
        assistant_name=data.assistant_name,
        seller_link=data.seller_link,
        greeting_message=data.greeting_message,
        bot_description=data.bot_description,
        is_active=True,
    )
    db.add(channel)
    await db.commit()
    await db.refresh(channel)
    return _channel_response(channel)


@router.get("/instagram", response_model=ChannelResponse | None)
async def get_instagram(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "instagram")
    if not ch:
        return None
    return _channel_response(ch)


@router.put("/instagram", response_model=ChannelResponse)
async def update_instagram(
    data: ChannelUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "instagram")
    if not ch:
        raise HTTPException(status_code=404, detail="No Instagram channel connected")

    ch.assistant_name = data.assistant_name
    ch.seller_link = data.seller_link
    ch.greeting_message = data.greeting_message
    ch.bot_description = data.bot_description
    if data.allow_partners is not None:
        ch.allow_partners = data.allow_partners

    await db.commit()
    await db.refresh(ch)
    return _channel_response(ch)


@router.delete("/instagram")
async def disconnect_instagram(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "instagram")
    if not ch:
        raise HTTPException(status_code=404, detail="No Instagram channel connected")

    await db.delete(ch)
    await db.commit()
    return {"message": "Instagram channel disconnected"}


# ── Messenger endpoints ──

@router.post("/messenger/connect", response_model=ChannelResponse, status_code=201)
async def connect_messenger(
    data: ChannelConnectRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Connect Facebook Messenger via Page access token."""
    user = await _load_user_channels(user, db)
    if _get_channel_by_platform(user, "facebook_messenger"):
        raise HTTPException(status_code=400, detail="You already have a Messenger channel connected")

    from app.services.meta_client import MetaClient
    meta = MetaClient()

    token_data = await meta.exchange_code_for_token(data.code)
    short_token = token_data.get("access_token")
    if not short_token:
        raise HTTPException(status_code=400, detail="Failed to exchange authorization code")

    long_token_data = await meta.get_long_lived_token(short_token)
    access_token = long_token_data.get("access_token", short_token)

    page_info = await meta.get_page_info(access_token)
    if not page_info:
        raise HTTPException(status_code=400, detail="Could not retrieve Page info")

    page_id = page_info.get("id", "")
    if page_id:
        await meta.subscribe_webhook(access_token, page_id)

    channel = Channel(
        user_id=user.id,
        platform="facebook_messenger",
        channel_name=page_info.get("name", "Messenger"),
        meta_page_id=page_id,
        access_token_encrypted=encrypt_token(access_token),
        webhook_status="active",
        assistant_name=data.assistant_name,
        seller_link=data.seller_link,
        greeting_message=data.greeting_message,
        bot_description=data.bot_description,
        is_active=True,
    )
    db.add(channel)
    await db.commit()
    await db.refresh(channel)
    return _channel_response(channel)


@router.get("/messenger", response_model=ChannelResponse | None)
async def get_messenger(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "facebook_messenger")
    if not ch:
        return None
    return _channel_response(ch)


@router.put("/messenger", response_model=ChannelResponse)
async def update_messenger(
    data: ChannelUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "facebook_messenger")
    if not ch:
        raise HTTPException(status_code=404, detail="No Messenger channel connected")

    ch.assistant_name = data.assistant_name
    ch.seller_link = data.seller_link
    ch.greeting_message = data.greeting_message
    ch.bot_description = data.bot_description
    if data.allow_partners is not None:
        ch.allow_partners = data.allow_partners

    await db.commit()
    await db.refresh(ch)
    return _channel_response(ch)


@router.delete("/messenger")
async def disconnect_messenger(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = _get_channel_by_platform(user, "facebook_messenger")
    if not ch:
        raise HTTPException(status_code=404, detail="No Messenger channel connected")

    await db.delete(ch)
    await db.commit()
    return {"message": "Messenger channel disconnected"}


# ── Status & Avatar ──

@router.get("/status", response_model=ChannelStatusResponse)
async def channel_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ig = _get_channel_by_platform(user, "instagram")
    msg = _get_channel_by_platform(user, "facebook_messenger")
    return ChannelStatusResponse(
        instagram=_channel_response(ig) if ig else None,
        messenger=_channel_response(msg) if msg else None,
    )


@router.post("/{channel_id}/avatar", response_model=ChannelResponse)
async def upload_avatar(
    channel_id: int,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_channels(user, db)
    ch = next((c for c in user.channels if c.id == channel_id), None)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, WEBP images are allowed")

    content = await file.read()
    if len(content) > settings.MAX_AVATAR_SIZE:
        raise HTTPException(status_code=400, detail="File is too large (max 5MB)")

    try:
        img = Image.open(BytesIO(content))
        img.verify()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")

    upload_dir = Path(settings.UPLOAD_DIR) / "avatars"
    upload_dir.mkdir(parents=True, exist_ok=True)
    filename = f"channel_{ch.id}.png"
    filepath = upload_dir / filename

    img = Image.open(BytesIO(content))
    img = img.convert("RGB")
    img.thumbnail((512, 512))
    img.save(filepath, "PNG")

    ch.avatar_url = f"/uploads/avatars/{filename}?v={int(time.time())}"
    await db.commit()
    await db.refresh(ch)
    return _channel_response(ch)
