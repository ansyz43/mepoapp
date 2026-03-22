import secrets
import datetime
import random
import logging
from email.message import EmailMessage
import aiosmtplib
import httpx

from fastapi import APIRouter, Depends, HTTPException, Response, Request, status
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.database import get_db
from app.models import User, PasswordResetToken, Channel, ReferralPartner
from app.config import settings
from app.schemas import (
    RegisterRequest, LoginRequest, TokenResponse, RefreshRequest,
    ResetPasswordRequest, SetPasswordRequest, VerifyCodeRequest,
    AppleAuthRequest, GoogleAuthRequest,
)
from app.auth import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])
limiter = Limiter(key_func=get_remote_address)
logger = logging.getLogger(__name__)


async def _auto_create_partnership(db, user_id: int, referrer_id: int):
    """If the referrer has a channel with allow_partners, auto-create a partnership."""
    result = await db.execute(
        select(Channel).where(
            Channel.user_id == referrer_id,
            Channel.allow_partners == True,
            Channel.is_active == True,
        )
    )
    channel = result.scalar_one_or_none()
    if not channel:
        return
    existing = await db.execute(
        select(ReferralPartner).where(
            ReferralPartner.user_id == user_id,
            ReferralPartner.channel_id == channel.id,
        )
    )
    if existing.scalar_one_or_none():
        return
    partner = ReferralPartner(
        user_id=user_id,
        channel_id=channel.id,
        seller_link=channel.seller_link or "https://example.com",
        ref_code=secrets.token_urlsafe(6),
        credits=5,
    )
    db.add(partner)
    await db.flush()


def _generate_user_ref_code() -> str:
    return secrets.token_urlsafe(6)


def _generate_reset_code() -> str:
    return str(random.SystemRandom().randint(100000, 999999))


async def _send_reset_email(email: str, code: str):
    if not settings.SMTP_HOST:
        logger.warning("SMTP not configured, reset code not sent for %s", email)
        return

    msg = EmailMessage()
    msg["Subject"] = "Meepo — Password Reset Code"
    msg["From"] = settings.SMTP_FROM or settings.SMTP_USER
    msg["To"] = email
    msg.set_content(
        f"Your password reset code: {code}\n\n"
        f"This code is valid for 15 minutes.\n\n"
        f"If you didn't request a password reset, please ignore this email."
    )

    await aiosmtplib.send(
        msg,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USER or None,
        password=settings.SMTP_PASSWORD or None,
        start_tls=True,
    )


@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("5/minute")
async def register(request: Request, data: RegisterRequest, response: Response, db: AsyncSession = Depends(get_db)):
    await db.execute(
        delete(PasswordResetToken).where(
            (PasswordResetToken.expires_at < func.now()) |
            (PasswordResetToken.used == True)
        )
    )

    existing = await db.execute(select(User).where(User.email == data.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    referred_by_id = None
    if data.ref_code:
        result = await db.execute(select(User).where(User.ref_code == data.ref_code))
        referrer = result.scalar_one_or_none()
        if referrer:
            referred_by_id = referrer.id

    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        name=data.name,
        auth_provider="email",
        ref_code=_generate_user_ref_code(),
        referred_by_id=referred_by_id,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    if referred_by_id:
        await _auto_create_partnership(db, user.id, referred_by_id)
        await db.commit()

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, data: LoginRequest, response: Response, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    user_id = decode_token(data.refresh_token, expected_type="refresh")
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    result = await db.execute(select(User).where(User.id == user_id, User.is_active == True))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/reset-password")
@limiter.limit("3/minute")
async def reset_password(request: Request, data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user:
        return {"message": "If this email is registered, a code has been sent"}

    await db.execute(
        delete(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used == False,
        )
    )

    code = _generate_reset_code()
    reset = PasswordResetToken(
        user_id=user.id,
        token=code,
        expires_at=datetime.datetime.now(datetime.UTC) + datetime.timedelta(minutes=15),
    )
    db.add(reset)
    await db.commit()

    try:
        await _send_reset_email(data.email, code)
    except Exception:
        logger.exception("Failed to send reset email to %s", data.email)

    return {"message": "If this email is registered, a code has been sent"}


@router.post("/verify-code")
@limiter.limit("10/minute")
async def verify_code(request: Request, data: VerifyCodeRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.token == data.code,
            PasswordResetToken.used == False,
            PasswordResetToken.expires_at > func.now(),
        )
    )
    reset = result.scalar_one_or_none()
    if not reset:
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    user_result = await db.execute(select(User).where(User.id == reset.user_id))
    user = user_result.scalar_one_or_none()
    if not user or user.email != data.email:
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    set_token = secrets.token_urlsafe(32)
    reset.token = set_token
    await db.commit()

    return {"token": set_token}


@router.post("/set-password")
async def set_password(data: SetPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.token == data.token,
            PasswordResetToken.used == False,
            PasswordResetToken.expires_at > func.now(),
        )
    )
    reset = result.scalar_one_or_none()
    if not reset:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    user_result = await db.execute(select(User).where(User.id == reset.user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=400, detail="User not found")

    user.password_hash = hash_password(data.password)
    reset.used = True
    await db.commit()

    return {"message": "Password updated successfully"}


@router.post("/apple", response_model=TokenResponse)
@limiter.limit("10/minute")
async def auth_apple(
    request: Request,
    data: AppleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    from app.services.apple_auth import verify_apple_token

    apple_claims = await verify_apple_token(data.identity_token)
    if not apple_claims:
        raise HTTPException(status_code=401, detail="Invalid Apple identity token")

    apple_sub = apple_claims["sub"]
    apple_email = apple_claims.get("email")

    # Find existing user by apple_id
    result = await db.execute(select(User).where(User.apple_id == apple_sub))
    user = result.scalar_one_or_none()

    if not user and apple_email:
        # Check if email already exists
        result = await db.execute(select(User).where(User.email == apple_email))
        user = result.scalar_one_or_none()
        if user:
            user.apple_id = apple_sub
            if not user.auth_provider:
                user.auth_provider = "apple"

    if not user:
        referred_by_id = None
        if data.ref_code:
            ref_result = await db.execute(select(User).where(User.ref_code == data.ref_code))
            referrer = ref_result.scalar_one_or_none()
            if referrer:
                referred_by_id = referrer.id

        user = User(
            email=apple_email or f"apple_{apple_sub[:8]}@placeholder.meepo",
            name=data.name or "User",
            apple_id=apple_sub,
            auth_provider="apple",
            ref_code=_generate_user_ref_code(),
            referred_by_id=referred_by_id,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        if referred_by_id:
            await _auto_create_partnership(db, user.id, referred_by_id)
            await db.commit()
    else:
        await db.commit()

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/google", response_model=TokenResponse)
@limiter.limit("10/minute")
async def auth_google(
    request: Request,
    data: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=501, detail="Google login not configured")

    # Verify Google ID token
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"https://oauth2.googleapis.com/tokeninfo?id_token={data.credential}",
                timeout=10,
            )
            if resp.status_code != 200:
                raise HTTPException(status_code=401, detail="Invalid Google token")
            payload = resp.json()

        if payload.get("aud") != settings.GOOGLE_CLIENT_ID:
            raise HTTPException(status_code=401, detail="Invalid Google token audience")

        google_id = payload.get("sub")
        email = payload.get("email")
        name = payload.get("name", "User")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Failed to verify Google token")

    # Find or create user
    result = await db.execute(select(User).where(User.google_id == google_id))
    user = result.scalar_one_or_none()

    if not user and email:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            user.google_id = google_id

    if not user:
        referred_by_id = None
        if data.ref_code:
            ref_result = await db.execute(select(User).where(User.ref_code == data.ref_code))
            referrer = ref_result.scalar_one_or_none()
            if referrer:
                referred_by_id = referrer.id

        user = User(
            email=email,
            name=name,
            google_id=google_id,
            auth_provider="google",
            ref_code=_generate_user_ref_code(),
            referred_by_id=referred_by_id,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        if referred_by_id:
            await _auto_create_partnership(db, user.id, referred_by_id)
            await db.commit()
    else:
        await db.commit()

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/logout")
async def logout():
    return {"message": "Successfully logged out"}


@router.delete("/account")
async def delete_account(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Delete user account (App Store requirement)."""
    from app.auth import get_current_user
    user = await get_current_user(
        credentials=(await request.headers.get("Authorization", "").split(" ", 1)[-1:] or [""])[0],
        db=db,
    )
    # This is handled via dependency injection instead
    raise HTTPException(status_code=501, detail="Use DELETE /api/auth/account with auth header")
