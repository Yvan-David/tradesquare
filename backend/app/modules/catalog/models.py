"""SQLAlchemy models for TradeSquare marketplace tables (Supabase/Postgres)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, ENUM, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base

user_role_enum = ENUM(
    "business_owner",
    "buyer",
    "supplier",
    "administrator",
    name="user_role",
    create_type=False,
)
user_status_enum = ENUM(
    "active", "pending", "inactive", name="user_status", create_type=False
)
verification_status_enum = ENUM(
    "not_submitted",
    "submitted",
    "under_review",
    "additional_information_required",
    "approved",
    "rejected",
    name="verification_status",
    create_type=False,
)
connection_status_enum = ENUM(
    "pending",
    "accepted",
    "rejected",
    "blocked",
    name="connection_status",
    create_type=False,
)
message_type_enum = ENUM(
    "text", "attachment", "voice", "image", name="message_type", create_type=False
)
read_status_enum = ENUM("read", "unread", name="read_status", create_type=False)


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(String)
    country: Mapped[str | None] = mapped_column(String)
    city: Mapped[str | None] = mapped_column(String)
    preferred_language: Mapped[str] = mapped_column(String, default="en")
    role: Mapped[str] = mapped_column(user_role_enum, nullable=False)
    status: Mapped[str] = mapped_column(user_status_enum, nullable=False)
    business_id: Mapped[str | None] = mapped_column(String, ForeignKey("businesses.id"))
    join_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    profile_completeness: Mapped[int] = mapped_column(Integer, default=0)
    photo_url: Mapped[str | None] = mapped_column(String)
    auth_user_id: Mapped[Any | None] = mapped_column(UUID(as_uuid=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Business(Base):
    __tablename__ = "businesses"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String)
    description: Mapped[str] = mapped_column(Text, default="")
    industry: Mapped[str] = mapped_column(String, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    country: Mapped[str] = mapped_column(String, nullable=False)
    province: Mapped[str | None] = mapped_column(String)
    city: Mapped[str] = mapped_column(String, nullable=False)
    address: Mapped[str | None] = mapped_column(String)
    email: Mapped[str | None] = mapped_column(String)
    phone: Mapped[str | None] = mapped_column(String)
    website: Mapped[str | None] = mapped_column(String)
    registration_number: Mapped[str | None] = mapped_column(String)
    registration_certificate_type: Mapped[str | None] = mapped_column(String)
    certificate_submission_status: Mapped[str | None] = mapped_column(String)
    verification_status: Mapped[str] = mapped_column(verification_status_enum)
    business_size: Mapped[str | None] = mapped_column(String)
    year_established: Mapped[int | None] = mapped_column(Integer)
    products_offered: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    products_needed: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    business_interests: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    preferred_markets: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    owner_id: Mapped[str | None] = mapped_column(String, ForeignKey("profiles.id"))
    profile_completeness: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    industry: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")


class ProductListing(Base):
    __tablename__ = "product_listings"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    business_id: Mapped[str] = mapped_column(String, ForeignKey("businesses.id"))
    name: Mapped[str] = mapped_column(String, nullable=False)
    product_image: Mapped[str | None] = mapped_column(String)
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String)
    industry: Mapped[str] = mapped_column(String)
    condition: Mapped[str] = mapped_column(String, default="New")
    unit: Mapped[str] = mapped_column(String, default="kg")
    available_quantity: Mapped[int] = mapped_column(Integer, default=0)
    minimum_order_quantity: Mapped[int] = mapped_column(Integer, default=0)
    indicative_price: Mapped[Any] = mapped_column(Numeric(14, 2), default=0)
    currency: Mapped[str] = mapped_column(String, default="USD")
    country_of_origin: Mapped[str | None] = mapped_column(String)
    delivery_locations: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    availability_status: Mapped[str] = mapped_column(String, default="In stock")
    listing_status: Mapped[str] = mapped_column(String, default="Active")
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    views: Mapped[int] = mapped_column(Integer, default=0)
    saved_count: Mapped[int] = mapped_column(Integer, default=0)


class BuyingRequest(Base):
    __tablename__ = "buying_requests"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    buyer_business_id: Mapped[str] = mapped_column(String, ForeignKey("businesses.id"))
    product_or_service: Mapped[str] = mapped_column(String)
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String)
    required_quantity: Mapped[int] = mapped_column(Integer, default=0)
    unit: Mapped[str] = mapped_column(String, default="kg")
    target_price_range: Mapped[str | None] = mapped_column(String)
    currency: Mapped[str] = mapped_column(String, default="USD")
    delivery_destination: Mapped[str | None] = mapped_column(String)
    preferred_supplier_location: Mapped[str | None] = mapped_column(String)
    deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    urgency: Mapped[str] = mapped_column(String, default="Medium")
    status: Mapped[str] = mapped_column(String, default="Open")
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class BusinessConnection(Base):
    __tablename__ = "business_connections"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    requesting_business_id: Mapped[str] = mapped_column(String, ForeignKey("businesses.id"))
    receiving_business_id: Mapped[str] = mapped_column(String, ForeignKey("businesses.id"))
    status: Mapped[str] = mapped_column(connection_status_enum)
    request_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    relationship_type: Mapped[str] = mapped_column(String)
    introductory_message: Mapped[str | None] = mapped_column(Text)


class BusinessVerification(Base):
    __tablename__ = "business_verifications"

    business_id: Mapped[str] = mapped_column(
        String, ForeignKey("businesses.id"), primary_key=True
    )
    status: Mapped[str] = mapped_column(verification_status_enum)
    review_message: Mapped[str] = mapped_column(Text, default="")
    last_updated: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    business_relationship: Mapped[str] = mapped_column(String, default="supplier")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    participants: Mapped[list["ConversationParticipant"]] = relationship(
        back_populates="conversation"
    )
    messages: Mapped[list["Message"]] = relationship(back_populates="conversation")


class ConversationParticipant(Base):
    __tablename__ = "conversation_participants"

    conversation_id: Mapped[str] = mapped_column(
        String, ForeignKey("conversations.id"), primary_key=True
    )
    profile_id: Mapped[str] = mapped_column(
        String, ForeignKey("profiles.id"), primary_key=True
    )
    conversation: Mapped[Conversation] = relationship(back_populates="participants")


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    conversation_id: Mapped[str] = mapped_column(String, ForeignKey("conversations.id"))
    sender_id: Mapped[str] = mapped_column(String, ForeignKey("profiles.id"))
    body: Mapped[str] = mapped_column(Text, default="")
    message_type: Mapped[str] = mapped_column(message_type_enum)
    read_status: Mapped[str] = mapped_column(read_status_enum)
    attachment_name: Mapped[str | None] = mapped_column(String)
    voice_duration: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    conversation: Mapped[Conversation] = relationship(back_populates="messages")


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    type: Mapped[str] = mapped_column(String)
    title: Mapped[str] = mapped_column(String)
    description: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    recipient_id: Mapped[str] = mapped_column(String, ForeignKey("profiles.id"))
    destination: Mapped[str] = mapped_column(String)


class FeedItem(Base):
    __tablename__ = "feed_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    type: Mapped[str] = mapped_column(String)
    source_business_id: Mapped[str | None] = mapped_column(
        String, ForeignKey("businesses.id")
    )
    title: Mapped[str] = mapped_column(String)
    summary: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    relevance_explanation: Mapped[str] = mapped_column(Text, default="")
    action_metadata: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict)


class AnalyticsSummary(Base):
    __tablename__ = "analytics_summaries"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    business_id: Mapped[str | None] = mapped_column(String, ForeignKey("businesses.id"))
    metric: Mapped[str] = mapped_column(String)
    value: Mapped[Any] = mapped_column(Numeric)
    delta: Mapped[Any] = mapped_column(Numeric)
    period: Mapped[str] = mapped_column(String)
    unit: Mapped[str] = mapped_column(String)


class InterestOption(Base):
    __tablename__ = "interest_options"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    label: Mapped[str] = mapped_column(String, unique=True)


class MarketInsight(Base):
    __tablename__ = "market_insights"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    industry: Mapped[str] = mapped_column(String)
    title: Mapped[str] = mapped_column(String)
    summary: Mapped[str] = mapped_column(Text, default="")
    region: Mapped[str | None] = mapped_column(String)
    metric_label: Mapped[str | None] = mapped_column(String)
    value: Mapped[str | None] = mapped_column(String)
    currency: Mapped[str | None] = mapped_column(String)
    insight_date: Mapped[date | None] = mapped_column(Date)
    source: Mapped[str | None] = mapped_column(String)
    is_illustrative: Mapped[bool] = mapped_column(Boolean, default=False)
