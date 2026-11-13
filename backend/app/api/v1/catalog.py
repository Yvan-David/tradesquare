"""REST catalog backed by Supabase (SQLAlchemy or PostgREST)."""

from __future__ import annotations

import os
from collections.abc import Iterator
from types import SimpleNamespace
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.database.session import DatabaseNotConfiguredError, create_session_factory
from app.integrations.supabase_rest import (
    SupabaseRestError,
    as_row,
    as_rows,
    rest_get,
    supabase_rest_configured,
)
from app.modules.catalog import models as m
from app.modules.catalog import serializers as s

router = APIRouter(prefix="/api/v1/catalog", tags=["catalog"])


def _sql_configured() -> bool:
    return bool(os.environ.get("DATABASE_URL", "").strip())


def get_catalog_db() -> Iterator[Session | None]:
    """Yield a SQLAlchemy session when DATABASE_URL is set; otherwise None (REST mode)."""
    if not _sql_configured():
        yield None
        return
    try:
        session = create_session_factory()()
    except DatabaseNotConfiguredError:
        yield None
        return
    try:
        yield session
    finally:
        session.close()


def _require_backend() -> None:
    if not _sql_configured() and not supabase_rest_configured():
        raise HTTPException(
            status_code=503,
            detail=(
                "Set DATABASE_URL (Postgres URI) or SUPABASE_URL + SUPABASE_ANON_KEY "
                "in .env, then apply supabase/migrations and seed.sql."
            ),
        )


def _assemble_conversations_rest() -> list[Any]:
    conversations = rest_get("conversations", params={"select": "*"})
    participants = rest_get("conversation_participants", params={"select": "*"})
    messages = rest_get(
        "messages", params={"select": "*", "order": "created_at.asc"}
    )
    parts_by_conv: dict[str, list[SimpleNamespace]] = {}
    for row in participants:
        parts_by_conv.setdefault(row["conversation_id"], []).append(
            SimpleNamespace(profile_id=row["profile_id"])
        )
    msgs_by_conv: dict[str, list[SimpleNamespace]] = {}
    for row in messages:
        msgs_by_conv.setdefault(row["conversation_id"], []).append(as_row(row))
    assembled: list[SimpleNamespace] = []
    for conv in conversations:
        item = as_row(conv)
        item.participants = parts_by_conv.get(conv["id"], [])
        item.messages = msgs_by_conv.get(conv["id"], [])
        assembled.append(item)
    return assembled


def _bootstrap_rest() -> dict[str, Any]:
    try:
        return {
            "profiles": [s.profile_to_api(r) for r in as_rows(rest_get("profiles"))],
            "businesses": [
                s.business_to_api(r) for r in as_rows(rest_get("businesses"))
            ],
            "products": [
                s.product_to_api(r) for r in as_rows(rest_get("product_listings"))
            ],
            "buyingRequests": [
                s.buying_request_to_api(r)
                for r in as_rows(rest_get("buying_requests"))
            ],
            "connections": [
                s.connection_to_api(r)
                for r in as_rows(rest_get("business_connections"))
            ],
            "verifications": [
                s.verification_to_api(r)
                for r in as_rows(rest_get("business_verifications"))
            ],
            "categories": [
                s.category_to_api(r) for r in as_rows(rest_get("categories"))
            ],
            "interests": [r["label"] for r in rest_get("interest_options")],
            "notifications": [
                s.notification_to_api(r) for r in as_rows(rest_get("notifications"))
            ],
            "feed": [s.feed_item_to_api(r) for r in as_rows(rest_get("feed_items"))],
            "analytics": [
                s.analytics_to_api(r) for r in as_rows(rest_get("analytics_summaries"))
            ],
            "conversations": [
                s.conversation_to_api(r) for r in _assemble_conversations_rest()
            ],
        }
    except SupabaseRestError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/health")
def catalog_health(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    if db is not None:
        try:
            businesses = db.scalar(select(m.Business.id).limit(1))
            return {
                "ok": True,
                "mode": "sqlalchemy",
                "database": "connected",
                "has_seed": businesses is not None,
            }
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "mode": "sqlalchemy", "detail": str(exc)}
    if supabase_rest_configured():
        try:
            rows = rest_get("businesses", params={"select": "id", "limit": "1"})
            return {
                "ok": True,
                "mode": "supabase_rest",
                "database": "connected",
                "has_seed": bool(rows),
            }
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "mode": "supabase_rest", "detail": str(exc)}
    return {"ok": False, "detail": "No DATABASE_URL or SUPABASE_URL configured"}


@router.get("/profiles")
def list_profiles(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(select(m.Profile).order_by(m.Profile.id)).all()
        return {"items": [s.profile_to_api(r) for r in rows]}
    return {"items": [s.profile_to_api(r) for r in as_rows(rest_get("profiles"))]}


@router.get("/profiles/{profile_id}")
def get_profile(
    profile_id: str, db: Session | None = Depends(get_catalog_db)
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        row = db.get(m.Profile, profile_id)
        if row is None:
            raise HTTPException(status_code=404, detail="profile not found")
        return s.profile_to_api(row)
    rows = rest_get("profiles", params={"select": "*", "id": f"eq.{profile_id}"})
    if not rows:
        raise HTTPException(status_code=404, detail="profile not found")
    return s.profile_to_api(as_row(rows[0]))


@router.get("/businesses")
def list_businesses(
    q: str | None = Query(None),
    industry: str | None = Query(None),
    db: Session | None = Depends(get_catalog_db),
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        stmt = select(m.Business).order_by(m.Business.name)
        if industry:
            stmt = stmt.where(m.Business.industry.ilike(industry))
        items = [s.business_to_api(r) for r in db.scalars(stmt).all()]
    else:
        params: dict[str, str] = {"select": "*", "order": "name.asc"}
        if industry:
            params["industry"] = f"ilike.*{industry}*"
        items = [s.business_to_api(r) for r in as_rows(rest_get("businesses", params=params))]
    if q:
        needle = q.strip().lower()
        items = [
            item
            for item in items
            if needle in item["name"].lower()
            or needle in item["description"].lower()
            or needle in item["city"].lower()
            or needle in item["industry"].lower()
        ]
    return {"items": items}


@router.get("/businesses/{business_id}")
def get_business(
    business_id: str, db: Session | None = Depends(get_catalog_db)
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        row = db.get(m.Business, business_id)
        if row is None:
            raise HTTPException(status_code=404, detail="business not found")
        return s.business_to_api(row)
    rows = rest_get("businesses", params={"select": "*", "id": f"eq.{business_id}"})
    if not rows:
        raise HTTPException(status_code=404, detail="business not found")
    return s.business_to_api(as_row(rows[0]))


@router.get("/products")
def list_products(
    business_id: str | None = Query(None),
    db: Session | None = Depends(get_catalog_db),
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        stmt = select(m.ProductListing).order_by(m.ProductListing.published_at.desc())
        if business_id:
            stmt = stmt.where(m.ProductListing.business_id == business_id)
        return {"items": [s.product_to_api(r) for r in db.scalars(stmt).all()]}
    params: dict[str, str] = {"select": "*", "order": "published_at.desc"}
    if business_id:
        params["business_id"] = f"eq.{business_id}"
    return {
        "items": [
            s.product_to_api(r)
            for r in as_rows(rest_get("product_listings", params=params))
        ]
    }


@router.get("/buying-requests")
def list_buying_requests(
    buyer_business_id: str | None = Query(None),
    db: Session | None = Depends(get_catalog_db),
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        stmt = select(m.BuyingRequest).order_by(m.BuyingRequest.published_at.desc())
        if buyer_business_id:
            stmt = stmt.where(m.BuyingRequest.buyer_business_id == buyer_business_id)
        return {"items": [s.buying_request_to_api(r) for r in db.scalars(stmt).all()]}
    params: dict[str, str] = {"select": "*", "order": "published_at.desc"}
    if buyer_business_id:
        params["buyer_business_id"] = f"eq.{buyer_business_id}"
    return {
        "items": [
            s.buying_request_to_api(r)
            for r in as_rows(rest_get("buying_requests", params=params))
        ]
    }


@router.get("/connections")
def list_connections(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(
            select(m.BusinessConnection).order_by(
                m.BusinessConnection.request_date.desc()
            )
        ).all()
        return {"items": [s.connection_to_api(r) for r in rows]}
    return {
        "items": [
            s.connection_to_api(r)
            for r in as_rows(rest_get("business_connections"))
        ]
    }


@router.get("/verifications")
def list_verifications(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        return {
            "items": [
                s.verification_to_api(r)
                for r in db.scalars(select(m.BusinessVerification)).all()
            ]
        }
    return {
        "items": [
            s.verification_to_api(r)
            for r in as_rows(rest_get("business_verifications"))
        ]
    }


@router.get("/categories")
def list_categories(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(select(m.Category).order_by(m.Category.name)).all()
        return {"items": [s.category_to_api(r) for r in rows]}
    return {
        "items": [
            s.category_to_api(r)
            for r in as_rows(
                rest_get("categories", params={"select": "*", "order": "name.asc"})
            )
        ]
    }


@router.get("/interests")
def list_interests(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(select(m.InterestOption).order_by(m.InterestOption.label)).all()
        return {"items": [r.label for r in rows]}
    return {"items": [r["label"] for r in rest_get("interest_options")]}


@router.get("/notifications")
def list_notifications(
    recipient_id: str | None = Query(None),
    db: Session | None = Depends(get_catalog_db),
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        stmt = select(m.Notification).order_by(m.Notification.created_at.desc())
        if recipient_id:
            stmt = stmt.where(m.Notification.recipient_id == recipient_id)
        return {"items": [s.notification_to_api(r) for r in db.scalars(stmt).all()]}
    params: dict[str, str] = {"select": "*", "order": "created_at.desc"}
    if recipient_id:
        params["recipient_id"] = f"eq.{recipient_id}"
    return {
        "items": [
            s.notification_to_api(r)
            for r in as_rows(rest_get("notifications", params=params))
        ]
    }


@router.get("/feed")
def list_feed(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(select(m.FeedItem).order_by(m.FeedItem.created_at.desc())).all()
        return {"items": [s.feed_item_to_api(r) for r in rows]}
    return {
        "items": [
            s.feed_item_to_api(r)
            for r in as_rows(
                rest_get(
                    "feed_items",
                    params={"select": "*", "order": "created_at.desc"},
                )
            )
        ]
    }


@router.get("/analytics")
def list_analytics(
    business_id: str | None = Query(None),
    db: Session | None = Depends(get_catalog_db),
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        stmt = select(m.AnalyticsSummary)
        if business_id:
            stmt = stmt.where(m.AnalyticsSummary.business_id == business_id)
        return {"items": [s.analytics_to_api(r) for r in db.scalars(stmt).all()]}
    params: dict[str, str] = {"select": "*"}
    if business_id:
        params["business_id"] = f"eq.{business_id}"
    return {
        "items": [
            s.analytics_to_api(r)
            for r in as_rows(rest_get("analytics_summaries", params=params))
        ]
    }


@router.get("/conversations")
def list_conversations(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        rows = db.scalars(
            select(m.Conversation).options(
                selectinload(m.Conversation.participants),
                selectinload(m.Conversation.messages),
            )
        ).all()
        return {"items": [s.conversation_to_api(r) for r in rows]}
    return {"items": [s.conversation_to_api(r) for r in _assemble_conversations_rest()]}


@router.get("/conversations/{conversation_id}")
def get_conversation(
    conversation_id: str, db: Session | None = Depends(get_catalog_db)
) -> dict[str, Any]:
    _require_backend()
    if db is not None:
        row = db.scalars(
            select(m.Conversation)
            .where(m.Conversation.id == conversation_id)
            .options(
                selectinload(m.Conversation.participants),
                selectinload(m.Conversation.messages),
            )
        ).first()
        if row is None:
            raise HTTPException(status_code=404, detail="conversation not found")
        return s.conversation_to_api(row)
    for item in _assemble_conversations_rest():
        if item.id == conversation_id:
            return s.conversation_to_api(item)
    raise HTTPException(status_code=404, detail="conversation not found")


@router.get("/bootstrap")
def bootstrap_catalog(db: Session | None = Depends(get_catalog_db)) -> dict[str, Any]:
    """One-shot payload for Flutter app start."""
    _require_backend()
    if db is None:
        return _bootstrap_rest()
    return {
        "profiles": [s.profile_to_api(r) for r in db.scalars(select(m.Profile)).all()],
        "businesses": [
            s.business_to_api(r) for r in db.scalars(select(m.Business)).all()
        ],
        "products": [
            s.product_to_api(r) for r in db.scalars(select(m.ProductListing)).all()
        ],
        "buyingRequests": [
            s.buying_request_to_api(r) for r in db.scalars(select(m.BuyingRequest)).all()
        ],
        "connections": [
            s.connection_to_api(r)
            for r in db.scalars(select(m.BusinessConnection)).all()
        ],
        "verifications": [
            s.verification_to_api(r)
            for r in db.scalars(select(m.BusinessVerification)).all()
        ],
        "categories": [
            s.category_to_api(r) for r in db.scalars(select(m.Category)).all()
        ],
        "interests": [r.label for r in db.scalars(select(m.InterestOption)).all()],
        "notifications": [
            s.notification_to_api(r) for r in db.scalars(select(m.Notification)).all()
        ],
        "feed": [s.feed_item_to_api(r) for r in db.scalars(select(m.FeedItem)).all()],
        "analytics": [
            s.analytics_to_api(r) for r in db.scalars(select(m.AnalyticsSummary)).all()
        ],
        "conversations": [
            s.conversation_to_api(r)
            for r in db.scalars(
                select(m.Conversation).options(
                    selectinload(m.Conversation.participants),
                    selectinload(m.Conversation.messages),
                )
            ).all()
        ],
    }
