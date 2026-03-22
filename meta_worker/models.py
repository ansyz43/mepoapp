import datetime
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from meta_worker.database import Base


class Channel(Base):
    __tablename__ = "channels"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, nullable=False)
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="instagram")
    meta_page_id: Mapped[str | None] = mapped_column(String(100))
    meta_ig_account_id: Mapped[str | None] = mapped_column(String(100))
    meta_business_id: Mapped[str | None] = mapped_column(String(100))
    access_token_encrypted: Mapped[str] = mapped_column(String(1000), nullable=False)
    token_expires_at: Mapped[datetime.datetime | None] = mapped_column(DateTime)
    channel_name: Mapped[str | None] = mapped_column(String(255))
    assistant_name: Mapped[str] = mapped_column(String(255), nullable=False, default="Assistant")
    seller_link: Mapped[str | None] = mapped_column(String(500))
    greeting_message: Mapped[str | None] = mapped_column(Text)
    bot_description: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    allow_partners: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    ref_code: Mapped[str | None] = mapped_column(String(16), unique=True)
    referred_by_id: Mapped[int | None] = mapped_column(Integer)
    cashback_balance: Mapped[float] = mapped_column(Float, default=0.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class Contact(Base):
    __tablename__ = "contacts"
    __table_args__ = (
        UniqueConstraint("channel_id", "channel_user_id", name="uq_contact_channel_user"),
    )
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    channel_id: Mapped[int] = mapped_column(Integer, ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="instagram")
    channel_user_id: Mapped[str | None] = mapped_column(String(100))
    channel_username: Mapped[str | None] = mapped_column(String(255))
    profile_pic_url: Mapped[str | None] = mapped_column(String(500))
    first_name: Mapped[str | None] = mapped_column(String(255))
    last_name: Mapped[str | None] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(50))
    first_message_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())
    last_message_at: Mapped[datetime.datetime | None] = mapped_column(DateTime)
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    link_sent: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")


class Message(Base):
    __tablename__ = "messages"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    contact_id: Mapped[int] = mapped_column(Integer, ForeignKey("contacts.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class ReferralPartner(Base):
    __tablename__ = "referral_partners"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, nullable=False)
    channel_id: Mapped[int] = mapped_column(Integer, ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    seller_link: Mapped[str] = mapped_column(String(500), nullable=False)
    ref_code: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    credits: Mapped[int] = mapped_column(Integer, default=5)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class ReferralSession(Base):
    __tablename__ = "referral_sessions"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    partner_id: Mapped[int] = mapped_column(Integer, ForeignKey("referral_partners.id", ondelete="CASCADE"), nullable=False)
    contact_id: Mapped[int] = mapped_column(Integer, ForeignKey("contacts.id", ondelete="CASCADE"), nullable=False)
    channel_user_id: Mapped[str] = mapped_column(String(100), nullable=False)
    started_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())
    expires_at: Mapped[datetime.datetime] = mapped_column(DateTime, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
