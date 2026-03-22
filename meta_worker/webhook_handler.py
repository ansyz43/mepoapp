"""
Webhook handler — processes incoming Meta messages.

Replaces bot_worker/main.py Telegram handling with Meta Send API.
"""
import asyncio
import datetime
import logging
import time
from collections import OrderedDict

from sqlalchemy import select, update, func

from meta_worker.config import settings
from meta_worker.database import async_session
from meta_worker.models import Channel, User, Contact, Message, ReferralPartner, ReferralSession
from meta_worker.crypto import decrypt_token
from meta_worker.ai_service import get_ai_response
from meta_worker.meta_api import MetaAPI

logger = logging.getLogger(__name__)

_meta_api = MetaAPI()

# Deduplication
_processed_messages: OrderedDict[str, float] = OrderedDict()
_DEDUP_MAX_SIZE = 5000

# Limit concurrent AI requests
_ai_semaphore = asyncio.Semaphore(30)


def _utcnow() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None)


def _is_duplicate(key: str) -> bool:
    if len(_processed_messages) > _DEDUP_MAX_SIZE:
        _processed_messages.popitem(last=False)
    if key in _processed_messages:
        return True
    _processed_messages[key] = time.monotonic()
    return False


async def process_incoming_message(
    platform: str,
    page_id: str,
    sender_id: str,
    text: str,
):
    """Process an incoming message from Meta webhook."""
    dedup_key = f"{platform}:{page_id}:{sender_id}:{hash(text)}:{int(time.time() / 5)}"
    if _is_duplicate(dedup_key):
        return

    async with async_session() as db:
        # Find channel by page_id
        if platform == "instagram":
            channel = (await db.execute(
                select(Channel).where(
                    Channel.meta_ig_account_id == page_id,
                    Channel.is_active == True,
                )
            )).scalar_one_or_none()
        else:
            channel = (await db.execute(
                select(Channel).where(
                    Channel.meta_page_id == page_id,
                    Channel.is_active == True,
                )
            )).scalar_one_or_none()

        if not channel:
            logger.warning(f"No active channel for page_id={page_id} platform={platform}")
            return

        # Get or create contact
        contact = await _get_or_create_contact(db, channel.id, platform, sender_id)

        # Save user message
        await _save_message(db, contact.id, "user", text)
        await db.commit()

        # Get owner info
        owner = (await db.execute(
            select(User).where(User.id == channel.user_id)
        )).scalar_one_or_none()
        seller_name = owner.name if owner else "Seller"

        # Get chat history
        history = await _get_chat_history(db, contact.id)

        # Check for active referral session — use partner's seller_link if present
        ref_session, partner = await _get_active_referral_session(db, channel.id, sender_id)
        active_seller_link = channel.seller_link
        if ref_session and partner:
            active_seller_link = partner.seller_link

    # Generate AI response (outside DB session to avoid long locks)
    async with _ai_semaphore:
        try:
            ai_response = await get_ai_response(
                assistant_name=channel.assistant_name,
                seller_name=seller_name,
                has_seller_link=bool(active_seller_link),
                chat_history=history,
                user_message=text,
            )
        except Exception as e:
            logger.error(f"AI error for channel {channel.id}: {e}")
            ai_response = "Извините, произошла техническая ошибка. Пожалуйста, попробуйте ещё раз через минуту."

    # Replace [ССЫЛКА] placeholder with actual seller link
    if active_seller_link and "[ССЫЛКА]" in ai_response:
        ai_response = ai_response.replace("[ССЫЛКА]", active_seller_link)
        # Mark link as sent
        async with async_session() as db:
            await db.execute(
                update(Contact).where(Contact.id == contact.id).values(link_sent=True)
            )
            await db.commit()

    # Save AI response
    async with async_session() as db:
        await _save_message(db, contact.id, "assistant", ai_response)
        await db.commit()

    # Send via Meta API
    access_token = decrypt_token(channel.access_token_encrypted)
    success = await _meta_api.send_message(
        access_token=access_token,
        recipient_id=sender_id,
        text=ai_response,
    )
    if not success:
        logger.error(f"Failed to send message to {sender_id} on channel {channel.id}")


async def process_referral(
    platform: str,
    page_id: str,
    sender_id: str,
    ref_code: str,
):
    """Process a referral link click from m.me or ig.me."""
    async with async_session() as db:
        # Find channel
        if platform == "instagram":
            channel = (await db.execute(
                select(Channel).where(Channel.meta_ig_account_id == page_id, Channel.is_active == True)
            )).scalar_one_or_none()
        else:
            channel = (await db.execute(
                select(Channel).where(Channel.meta_page_id == page_id, Channel.is_active == True)
            )).scalar_one_or_none()

        if not channel:
            return

        # Find partner
        partner = (await db.execute(
            select(ReferralPartner).where(
                ReferralPartner.ref_code == ref_code,
                ReferralPartner.channel_id == channel.id,
                ReferralPartner.is_active == True,
            )
        )).scalar_one_or_none()

        if not partner:
            return

        # Get or create contact
        contact = await _get_or_create_contact(db, channel.id, platform, sender_id)

        # Check if already has a referral session
        already = await _is_referral_user(db, channel.id, sender_id)
        if already:
            return

        # Create referral session (deduct credit atomically)
        result = await db.execute(
            update(ReferralPartner)
            .where(ReferralPartner.id == partner.id, ReferralPartner.credits > 0)
            .values(credits=ReferralPartner.credits - 1)
            .returning(ReferralPartner.id)
        )
        if not result.scalar_one_or_none():
            return

        now = _utcnow()
        ref_session = ReferralSession(
            partner_id=partner.id,
            contact_id=contact.id,
            channel_user_id=sender_id,
            started_at=now,
            expires_at=now + datetime.timedelta(hours=12),
            is_active=True,
        )
        db.add(ref_session)
        await db.commit()

        logger.info(f"Referral session created: partner={partner.id}, contact={contact.id}, ref={ref_code}")


# ─── Helpers ───

async def _get_or_create_contact(
    db, channel_id: int, platform: str, sender_id: str
) -> Contact:
    result = await db.execute(
        select(Contact).where(
            Contact.channel_id == channel_id,
            Contact.channel_user_id == sender_id,
        )
    )
    contact = result.scalar_one_or_none()

    if contact:
        contact.last_message_at = _utcnow()
        contact.message_count += 1
        await db.flush()
        return contact

    # Get profile info from Meta
    profile = {}
    try:
        # Need channel token to look up user - skip for now, will populate on next call
        pass
    except Exception:
        pass

    contact = Contact(
        channel_id=channel_id,
        platform=platform,
        channel_user_id=sender_id,
        channel_username=profile.get("name"),
        profile_pic_url=profile.get("profile_pic"),
        first_name=profile.get("name", "").split(" ")[0] if profile.get("name") else None,
        last_message_at=_utcnow(),
        message_count=1,
    )
    db.add(contact)
    await db.flush()
    await db.refresh(contact)
    return contact


async def _save_message(db, contact_id: int, role: str, content: str):
    msg = Message(contact_id=contact_id, role=role, content=content)
    db.add(msg)
    await db.flush()


async def _get_chat_history(db, contact_id: int, limit: int = 20) -> list[dict]:
    result = await db.execute(
        select(Message)
        .where(Message.contact_id == contact_id)
        .order_by(Message.created_at.desc())
        .limit(limit)
    )
    messages = list(reversed(result.scalars().all()))
    return [{"role": m.role, "content": m.content} for m in messages]


async def _get_active_referral_session(db, channel_id: int, sender_id: str):
    now = _utcnow()
    result = await db.execute(
        select(ReferralSession, ReferralPartner)
        .join(ReferralPartner, ReferralSession.partner_id == ReferralPartner.id)
        .where(
            ReferralPartner.channel_id == channel_id,
            ReferralSession.channel_user_id == sender_id,
        )
        .order_by(ReferralSession.started_at.desc())
        .limit(1)
    )
    row = result.first()
    if not row:
        return None, None
    ref_session, partner = row
    if not ref_session.is_active or ref_session.expires_at <= now:
        if ref_session.is_active:
            ref_session.is_active = False
            await db.flush()
        return None, None
    return ref_session, partner


async def _is_referral_user(db, channel_id: int, sender_id: str) -> bool:
    result = await db.execute(
        select(func.count(ReferralSession.id))
        .join(ReferralPartner, ReferralSession.partner_id == ReferralPartner.id)
        .where(
            ReferralPartner.channel_id == channel_id,
            ReferralSession.channel_user_id == sender_id,
        )
    )
    return (result.scalar() or 0) > 0
