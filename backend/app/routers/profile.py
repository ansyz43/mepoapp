import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import User, Channel
from app.schemas import ProfileResponse, ProfileUpdateRequest, ChangePasswordRequest
from app.auth import get_current_user, hash_password, verify_password

router = APIRouter(prefix="/api/profile", tags=["profile"])
logger = logging.getLogger(__name__)


async def _load_user_with_channels(user: User, db: AsyncSession) -> User:
    result = await db.execute(
        select(User).options(selectinload(User.channels)).where(User.id == user.id)
    )
    return result.scalar_one()


@router.get("", response_model=ProfileResponse)
async def get_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_with_channels(user, db)

    result = await db.execute(
        select(func.count(User.id)).where(User.referred_by_id == user.id)
    )
    referrals_count = result.scalar() or 0

    return ProfileResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        created_at=user.created_at,
        has_channel=len(user.channels) > 0,
        is_admin=user.is_admin,
        ref_code=user.ref_code,
        ref_link=f"https://meepo.app/register?ref={user.ref_code}" if user.ref_code else None,
        cashback_balance=user.cashback_balance or 0.0,
        referrals_count=referrals_count,
    )


@router.put("", response_model=ProfileResponse)
async def update_profile(
    data: ProfileUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_with_channels(user, db)
    user.name = data.name
    await db.commit()
    await db.refresh(user)

    result = await db.execute(
        select(func.count(User.id)).where(User.referred_by_id == user.id)
    )
    referrals_count = result.scalar() or 0

    return ProfileResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        created_at=user.created_at,
        has_channel=len(user.channels) > 0,
        is_admin=user.is_admin,
        ref_code=user.ref_code,
        ref_link=f"https://meepo.app/register?ref={user.ref_code}" if user.ref_code else None,
        cashback_balance=user.cashback_balance or 0.0,
        referrals_count=referrals_count,
    )


@router.put("/password")
async def change_password(
    data: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not user.password_hash:
        raise HTTPException(status_code=400, detail="Account uses social login, no password to change")

    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.password_hash = hash_password(data.new_password)
    await db.commit()
    return {"message": "Password changed successfully"}


@router.delete("")
async def delete_account(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete user account and all associated data (App Store requirement)."""
    user = await _load_user_with_channels(user, db)

    await db.delete(user)
    await db.commit()

    logger.info(f"User {user.email} (id={user.id}) deleted their account")
    return {"message": "Account deleted successfully"}
