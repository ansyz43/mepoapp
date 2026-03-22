import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import User, Channel, Contact, Message, Broadcast, ReferralPartner, ReferralSession, CashbackTransaction, PasswordResetToken
from app.auth import get_admin_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin"])


# ─── Stats ───────────────────────────────────────────
@router.get("/stats")
async def admin_stats(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    active_users = (await db.execute(select(func.count(User.id)).where(User.is_active == True))).scalar() or 0
    total_channels = (await db.execute(select(func.count(Channel.id)))).scalar() or 0
    active_channels = (await db.execute(select(func.count(Channel.id)).where(Channel.is_active == True))).scalar() or 0
    total_contacts = (await db.execute(select(func.count(Contact.id)))).scalar() or 0
    total_messages = (await db.execute(select(func.count(Message.id)))).scalar() or 0
    total_broadcasts = (await db.execute(select(func.count(Broadcast.id)))).scalar() or 0

    return {
        "total_users": total_users,
        "active_users": active_users,
        "total_channels": total_channels,
        "active_channels": active_channels,
        "total_contacts": total_contacts,
        "total_messages": total_messages,
        "total_broadcasts": total_broadcasts,
    }


# ─── Users ───────────────────────────────────────────
@router.get("/users")
async def admin_list_users(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    search: str = Query("", max_length=100),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    query = select(User).options(selectinload(User.channels))
    count_query = select(func.count(User.id))

    if search:
        flt = or_(User.name.ilike(f"%{search}%"), User.email.ilike(f"%{search}%"))
        query = query.where(flt)
        count_query = count_query.where(flt)

    total = (await db.execute(count_query)).scalar() or 0
    result = await db.execute(query.order_by(User.created_at.desc()).limit(limit).offset(offset))
    users = result.scalars().all()

    return {
        "users": [
            {
                "id": u.id,
                "email": u.email,
                "name": u.name,
                "is_active": u.is_active,
                "is_admin": u.is_admin,
                "auth_provider": u.auth_provider,
                "created_at": u.created_at.isoformat() if u.created_at else None,
                "channels": [
                    {
                        "id": c.id,
                        "platform": c.platform,
                        "channel_name": c.channel_name,
                        "is_active": c.is_active,
                    }
                    for c in u.channels
                ],
            }
            for u in users
        ],
        "total": total,
    }


@router.get("/users/{user_id}")
async def admin_get_user(
    user_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).options(selectinload(User.channels)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    channel_ids = [c.id for c in user.channels]
    contacts_count = 0
    messages_count = 0
    if channel_ids:
        contacts_count = (await db.execute(
            select(func.count(Contact.id)).where(Contact.channel_id.in_(channel_ids))
        )).scalar() or 0
        messages_count = (await db.execute(
            select(func.count(Message.id)).where(
                Message.contact_id.in_(select(Contact.id).where(Contact.channel_id.in_(channel_ids)))
            )
        )).scalar() or 0

    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "is_active": user.is_active,
        "is_admin": user.is_admin,
        "auth_provider": user.auth_provider,
        "apple_id": user.apple_id,
        "google_id": user.google_id,
        "ref_code": user.ref_code,
        "cashback_balance": float(user.cashback_balance or 0),
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "contacts_count": contacts_count,
        "messages_count": messages_count,
        "channels": [
            {
                "id": c.id,
                "platform": c.platform,
                "channel_name": c.channel_name,
                "assistant_name": c.assistant_name,
                "seller_link": c.seller_link,
                "is_active": c.is_active,
                "meta_page_id": c.meta_page_id,
                "meta_ig_account_id": c.meta_ig_account_id,
            }
            for c in user.channels
        ],
    }


@router.delete("/users/{user_id}")
async def admin_delete_user(
    user_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).options(selectinload(User.channels)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_admin:
        raise HTTPException(status_code=400, detail="Cannot delete administrator")

    # Deactivate channels
    for ch in user.channels:
        ch.is_active = False

    await db.delete(user)
    await db.commit()

    logger.info(f"Admin {admin.email} deleted user {user.email} (id={user_id})")
    return {"detail": f"User {user.email} deleted"}


@router.patch("/users/{user_id}/toggle")
async def admin_toggle_user(
    user_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_admin:
        raise HTTPException(status_code=400, detail="Cannot deactivate administrator")

    user.is_active = not user.is_active
    await db.commit()

    logger.info(f"Admin {admin.email} toggled user {user.email} is_active={user.is_active}")
    return {"id": user.id, "is_active": user.is_active}


# ─── Channels ────────────────────────────────────────
@router.get("/channels")
async def admin_list_channels(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    search: str = Query("", max_length=100),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    query = select(Channel).options(selectinload(Channel.owner))
    count_query = select(func.count(Channel.id))

    if search:
        flt = Channel.channel_name.ilike(f"%{search}%")
        query = query.where(flt)
        count_query = count_query.where(flt)

    total = (await db.execute(count_query)).scalar() or 0
    result = await db.execute(query.order_by(Channel.id).limit(limit).offset(offset))
    channels = result.scalars().all()

    channel_ids = [c.id for c in channels]
    contact_counts = {}
    if channel_ids:
        counts_result = await db.execute(
            select(Contact.channel_id, func.count(Contact.id))
            .where(Contact.channel_id.in_(channel_ids))
            .group_by(Contact.channel_id)
        )
        contact_counts = dict(counts_result.all())

    return {
        "channels": [
            {
                "id": c.id,
                "platform": c.platform,
                "channel_name": c.channel_name,
                "assistant_name": c.assistant_name,
                "seller_link": c.seller_link,
                "is_active": c.is_active,
                "meta_page_id": c.meta_page_id,
                "owner_email": c.owner.email if c.owner else None,
                "owner_name": c.owner.name if c.owner else None,
                "contacts_count": contact_counts.get(c.id, 0),
                "created_at": c.created_at.isoformat() if c.created_at else None,
            }
            for c in channels
        ],
        "total": total,
    }


@router.delete("/channels/{channel_id}")
async def admin_delete_channel(
    channel_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    channel = result.scalar_one_or_none()
    if not channel:
        raise HTTPException(status_code=404, detail="Channel not found")

    name = channel.channel_name
    await db.delete(channel)
    await db.commit()

    logger.info(f"Admin {admin.email} deleted channel {name} (id={channel_id})")
    return {"detail": f"Channel {name} deleted"}


# ─── Conversations ───────────────────────────────────
@router.get("/conversations/{contact_id}")
async def admin_view_conversation(
    contact_id: int,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    contact = (await db.execute(
        select(Contact).where(Contact.id == contact_id)
    )).scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")

    total = (await db.execute(
        select(func.count(Message.id)).where(Message.contact_id == contact_id)
    )).scalar() or 0

    messages = (await db.execute(
        select(Message)
        .where(Message.contact_id == contact_id)
        .order_by(Message.created_at)
        .limit(limit)
        .offset(offset)
    )).scalars().all()

    return {
        "contact": {
            "id": contact.id,
            "platform": contact.platform,
            "channel_user_id": contact.channel_user_id,
            "channel_username": contact.channel_username,
            "first_name": contact.first_name,
            "last_name": contact.last_name,
            "message_count": contact.message_count,
        },
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
        "total": total,
    }
