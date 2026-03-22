import asyncio
import datetime
import logging
import time
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy import select, func as sa_func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, async_session
from app.models import User, Channel, Contact, Broadcast
from app.schemas import BroadcastResponse
from app.auth import get_current_user
from app.services.crypto import decrypt_token
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/channel", tags=["broadcast"])

# 24-hour window for Meta messaging policy
WINDOW_HOURS = 24


async def _get_user_channel(user: User, db: AsyncSession) -> Channel:
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(User).options(selectinload(User.channels)).where(User.id == user.id)
    )
    u = result.scalar_one()
    channel = next((c for c in u.channels if c.is_active), None)
    if not channel:
        raise HTTPException(status_code=404, detail="No active channel connected")
    return channel


@router.post("/broadcast", response_model=BroadcastResponse, status_code=201)
async def create_broadcast(
    message_text: str = Form(..., min_length=1, max_length=4096),
    image: UploadFile | None = File(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    channel = await _get_user_channel(user, db)

    # Count total contacts
    count_result = await db.execute(
        select(sa_func.count(Contact.id)).where(Contact.channel_id == channel.id)
    )
    total = count_result.scalar() or 0
    if total == 0:
        raise HTTPException(status_code=400, detail="No contacts available for broadcast")

    # Count eligible contacts (within 24h window per Meta policy)
    window_cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(hours=WINDOW_HOURS)
    eligible_result = await db.execute(
        select(sa_func.count(Contact.id)).where(
            Contact.channel_id == channel.id,
            Contact.last_message_at >= window_cutoff,
        )
    )
    eligible = eligible_result.scalar() or 0

    # Handle image upload
    image_url = None
    if image and image.filename:
        if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
            raise HTTPException(status_code=400, detail="Only JPEG, PNG or WEBP allowed")
        content = await image.read()
        if len(content) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Maximum 5MB")
        upload_dir = Path(settings.UPLOAD_DIR) / "broadcasts"
        upload_dir.mkdir(parents=True, exist_ok=True)
        ext = image.filename.rsplit(".", 1)[-1] if "." in image.filename else "jpg"
        filename = f"bc_{channel.id}_{int(time.time())}.{ext}"
        filepath = upload_dir / filename
        with open(filepath, "wb") as f:
            f.write(content)
        image_url = f"/uploads/broadcasts/{filename}"

    broadcast = Broadcast(
        channel_id=channel.id,
        message_text=message_text,
        image_url=image_url,
        total_contacts=total,
        eligible_contacts=eligible,
        status="pending",
    )
    db.add(broadcast)
    await db.commit()
    await db.refresh(broadcast)

    # Fire background task
    asyncio.create_task(_send_broadcast(
        broadcast.id, channel.id,
        channel.access_token_encrypted,
        channel.platform,
    ))

    return broadcast


@router.get("/broadcasts", response_model=list[BroadcastResponse])
async def list_broadcasts(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    channel = await _get_user_channel(user, db)
    result = await db.execute(
        select(Broadcast)
        .where(Broadcast.channel_id == channel.id)
        .order_by(Broadcast.created_at.desc())
        .limit(50)
    )
    return result.scalars().all()


async def _send_broadcast(
    broadcast_id: int,
    channel_id: int,
    token_encrypted: str,
    platform: str,
):
    """Background task: send broadcast via Meta Send API with 24h window filtering."""
    from app.services.meta_client import MetaClient

    access_token = decrypt_token(token_encrypted)
    meta = MetaClient()

    async with async_session() as db:
        bc = await db.get(Broadcast, broadcast_id)
        if not bc:
            return
        bc.status = "sending"
        await db.commit()

        message_text = bc.message_text

        # Get eligible contacts (within 24h window)
        window_cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(hours=WINDOW_HOURS)
        result = await db.execute(
            select(Contact.channel_user_id).where(
                Contact.channel_id == channel_id,
                Contact.last_message_at >= window_cutoff,
                Contact.channel_user_id.isnot(None),
            )
        )
        recipient_ids = [row[0] for row in result.all()]

    sent = 0
    failed = 0

    for i, recipient_id in enumerate(recipient_ids):
        try:
            success = await meta.send_message(
                access_token=access_token,
                recipient_id=recipient_id,
                text=message_text,
                platform=platform,
            )
            if success:
                sent += 1
            else:
                failed += 1
        except Exception:
            failed += 1

        # Rate limit: Instagram 200/hour ≈ 3.3/sec, be conservative
        if (i + 1) % 3 == 0:
            await asyncio.sleep(1)

        # Update counts every 25 messages
        if (i + 1) % 25 == 0:
            async with async_session() as db:
                bc = await db.get(Broadcast, broadcast_id)
                if bc:
                    bc.sent_count = sent
                    bc.failed_count = failed
                    await db.commit()

    # Final update
    async with async_session() as db:
        bc = await db.get(Broadcast, broadcast_id)
        if bc:
            bc.sent_count = sent
            bc.failed_count = failed
            bc.status = "completed"
            await db.commit()

    logger.info(f"Broadcast {broadcast_id} done: sent={sent}, failed={failed}")
