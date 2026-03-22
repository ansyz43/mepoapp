import secrets
import datetime
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User, Channel, ReferralPartner, ReferralSession, Contact, CashbackTransaction
from app.schemas import (
    ChannelCatalogItem,
    ReferralPartnerCreate,
    ReferralPartnerUpdate,
    ReferralPartnerResponse,
    ReferralSessionResponse,
    AddCreditsRequest,
    ChannelPartnerInfo,
    TreeNodeResponse,
    CashbackTransactionResponse,
)
from app.auth import get_current_user

router = APIRouter(prefix="/api/referral", tags=["referral"])
logger = logging.getLogger(__name__)


def _generate_ref_code() -> str:
    return secrets.token_urlsafe(6)


def _partner_response(partner: ReferralPartner, channel: Channel) -> ReferralPartnerResponse:
    return ReferralPartnerResponse(
        id=partner.id,
        channel_id=partner.channel_id,
        channel_name=channel.channel_name,
        assistant_name=channel.assistant_name,
        seller_link=partner.seller_link,
        ref_code=partner.ref_code,
        ref_link=f"https://ig.me/m/{channel.channel_name}?ref=ref_{partner.ref_code}" if channel.channel_name else "",
        credits=partner.credits,
        is_active=partner.is_active,
        created_at=partner.created_at,
    )


@router.get("/catalog", response_model=list[ChannelCatalogItem])
async def get_catalog(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List channels that allow partners."""
    result = await db.execute(
        select(Channel).where(
            Channel.allow_partners == True,
            Channel.is_active == True,
            Channel.user_id.isnot(None),
        )
    )
    channels = result.scalars().all()
    return [
        ChannelCatalogItem(
            id=ch.id,
            channel_name=ch.channel_name,
            assistant_name=ch.assistant_name,
            avatar_url=ch.avatar_url,
        )
        for ch in channels
    ]


@router.post("/partner", response_model=ReferralPartnerResponse, status_code=201)
async def create_partner(
    data: ReferralPartnerCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Become a partner for a channel."""
    channel = await db.get(Channel, data.channel_id)
    if not channel or not channel.allow_partners or not channel.is_active:
        raise HTTPException(status_code=404, detail="Channel not found or not accepting partners")

    if channel.user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot be a partner of your own channel")

    existing = await db.execute(
        select(ReferralPartner).where(
            ReferralPartner.user_id == user.id,
            ReferralPartner.channel_id == data.channel_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You are already a partner of this channel")

    if user.referred_by_id is None and channel.user_id is not None:
        user.referred_by_id = channel.user_id

    partner = ReferralPartner(
        user_id=user.id,
        channel_id=data.channel_id,
        seller_link=data.seller_link,
        ref_code=_generate_ref_code(),
        credits=5,
    )
    db.add(partner)
    await db.commit()
    await db.refresh(partner)
    return _partner_response(partner, channel)


@router.get("/partner", response_model=ReferralPartnerResponse | None)
async def get_partner(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReferralPartner, Channel)
        .join(Channel, ReferralPartner.channel_id == Channel.id)
        .where(ReferralPartner.user_id == user.id)
        .limit(1)
    )
    row = result.first()
    if not row:
        return None
    partner, channel = row
    return _partner_response(partner, channel)


@router.put("/partner", response_model=ReferralPartnerResponse)
async def update_partner(
    data: ReferralPartnerUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReferralPartner, Channel)
        .join(Channel, ReferralPartner.channel_id == Channel.id)
        .where(ReferralPartner.user_id == user.id)
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Partnership not found")
    partner, channel = row
    partner.seller_link = data.seller_link
    await db.commit()
    await db.refresh(partner)
    return _partner_response(partner, channel)


@router.get("/sessions", response_model=list[ReferralSessionResponse])
async def get_sessions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReferralPartner).where(ReferralPartner.user_id == user.id)
    )
    partner = result.scalar_one_or_none()
    if not partner:
        return []

    result = await db.execute(
        select(ReferralSession, Contact)
        .join(Contact, ReferralSession.contact_id == Contact.id)
        .where(ReferralSession.partner_id == partner.id)
        .order_by(ReferralSession.started_at.desc())
        .limit(50)
    )
    rows = result.all()

    now = datetime.datetime.now(datetime.UTC)
    return [
        ReferralSessionResponse(
            id=session.id,
            channel_user_id=session.channel_user_id,
            channel_username=contact.channel_username,
            first_name=contact.first_name,
            started_at=session.started_at,
            expires_at=session.expires_at,
            is_active=session.is_active and session.expires_at > now,
        )
        for session, contact in rows
    ]


@router.post("/credits", response_model=ReferralPartnerResponse)
async def add_credits(
    data: AddCreditsRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    partner = await db.get(ReferralPartner, data.partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    channel = await db.get(Channel, partner.channel_id)
    if not channel or channel.user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the channel owner can add credits")

    await db.execute(
        update(ReferralPartner)
        .where(ReferralPartner.id == partner.id)
        .values(credits=ReferralPartner.credits + data.credits)
    )
    await _process_cashback(db, partner.user_id, float(data.credits), "credits")
    await db.commit()
    await db.refresh(partner)

    return _partner_response(partner, channel)


@router.get("/my-partners", response_model=list[ChannelPartnerInfo])
async def get_my_channel_partners(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Channel).where(Channel.user_id == user.id)
    )
    channel = result.scalar_one_or_none()
    if not channel:
        return []

    now = datetime.datetime.now(datetime.UTC)
    total_sessions_sq = (
        select(func.count(ReferralSession.id))
        .where(ReferralSession.partner_id == ReferralPartner.id)
        .correlate(ReferralPartner)
        .scalar_subquery()
    )
    active_sessions_sq = (
        select(func.count(ReferralSession.id))
        .where(
            ReferralSession.partner_id == ReferralPartner.id,
            ReferralSession.is_active == True,
            ReferralSession.expires_at > now,
        )
        .correlate(ReferralPartner)
        .scalar_subquery()
    )

    result = await db.execute(
        select(
            ReferralPartner, User,
            total_sessions_sq.label("total_sessions"),
            active_sessions_sq.label("active_sessions"),
        )
        .join(User, ReferralPartner.user_id == User.id)
        .where(ReferralPartner.channel_id == channel.id)
        .order_by(ReferralPartner.created_at.desc())
    )
    rows = result.all()

    return [
        ChannelPartnerInfo(
            id=partner.id,
            user_name=partner_user.name,
            user_email=partner_user.email,
            seller_link=partner.seller_link,
            ref_code=partner.ref_code,
            credits=partner.credits,
            total_sessions=total_sessions or 0,
            active_sessions=active_sessions or 0,
            created_at=partner.created_at,
        )
        for partner, partner_user, total_sessions, active_sessions in rows
    ]


@router.get("/my-cashback", response_model=list[CashbackTransactionResponse])
async def get_my_cashback(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CashbackTransaction, User)
        .join(User, CashbackTransaction.from_user_id == User.id)
        .where(CashbackTransaction.user_id == user.id)
        .order_by(CashbackTransaction.created_at.desc())
        .limit(100)
    )
    rows = result.all()
    return [
        CashbackTransactionResponse(
            id=tx.id,
            from_user_name=from_user.name,
            amount=float(tx.amount),
            source_amount=float(tx.source_amount),
            level=tx.level,
            source_type=tx.source_type,
            created_at=tx.created_at,
        )
        for tx, from_user in rows
    ]


# --- Cashback engine ---

CASHBACK_RATES = {1: 0.10, 2: 0.05, 3: 0.03, 4: 0.02}
DEFAULT_RATE = 0.01


async def _process_cashback(
    db: AsyncSession,
    spender_user_id: int,
    amount: float,
    source_type: str,
):
    """Walk up the referral chain and credit cashback at each level."""
    current_result = await db.execute(select(User).where(User.id == spender_user_id))
    current_user = current_result.scalar_one_or_none()
    if not current_user or not current_user.referred_by_id:
        return

    level = 1
    visited = {spender_user_id}
    referrer_id = current_user.referred_by_id

    while referrer_id and referrer_id not in visited and level <= 5:
        visited.add(referrer_id)
        referrer_result = await db.execute(select(User).where(User.id == referrer_id))
        referrer = referrer_result.scalar_one_or_none()
        if not referrer:
            break

        rate = CASHBACK_RATES.get(level, DEFAULT_RATE)
        cashback_amount = amount * rate

        if cashback_amount > 0.01:
            tx = CashbackTransaction(
                user_id=referrer.id,
                from_user_id=spender_user_id,
                amount=cashback_amount,
                source_amount=amount,
                level=level,
                source_type=source_type,
            )
            db.add(tx)
            referrer.cashback_balance = (referrer.cashback_balance or 0) + cashback_amount

        referrer_id = referrer.referred_by_id
        level += 1
