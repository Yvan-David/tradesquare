"""CamelCase JSON serializers matching the Flutter domain models."""

from __future__ import annotations

from datetime import datetime
from typing import Any

_ROLE_API = {
    "business_owner": "businessOwner",
    "buyer": "buyer",
    "supplier": "supplier",
    "administrator": "administrator",
}

_VERIFICATION_API = {
    "not_submitted": "notSubmitted",
    "submitted": "submitted",
    "under_review": "underReview",
    "additional_information_required": "additionalInformationRequired",
    "approved": "approved",
    "rejected": "rejected",
}


def _iso(value: datetime | str | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value.replace("+00:00", "Z")
    return value.isoformat().replace("+00:00", "Z")


def profile_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "fullName": row.full_name,
        "email": row.email,
        "phone": row.phone or "",
        "country": row.country or "",
        "city": row.city or "",
        "preferredLanguage": row.preferred_language,
        "role": _ROLE_API.get(str(row.role), str(row.role)),
        "status": str(row.status),
        "businessAssociation": row.business_id or "",
        "joinDate": _iso(row.join_date),
        "profileCompleteness": row.profile_completeness,
        "photoUrl": row.photo_url,
    }


def business_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "name": row.name,
        "logoUrl": row.logo_url or "",
        "description": row.description or "",
        "industry": row.industry,
        "category": row.category,
        "country": row.country,
        "province": row.province or "",
        "city": row.city,
        "address": row.address or "",
        "email": row.email or "",
        "phone": row.phone or "",
        "website": row.website or "",
        "registrationNumber": row.registration_number or "",
        "registrationCertificateType": row.registration_certificate_type or "",
        "certificateSubmissionStatus": row.certificate_submission_status or "",
        "verificationStatus": _VERIFICATION_API.get(
            str(row.verification_status), str(row.verification_status)
        ),
        "businessSize": row.business_size or "",
        "yearEstablished": row.year_established or 0,
        "productsOffered": list(row.products_offered or []),
        "productsNeeded": list(row.products_needed or []),
        "businessInterests": list(row.business_interests or []),
        "preferredMarkets": list(row.preferred_markets or []),
        "ownerId": row.owner_id or "",
        "profileCompleteness": row.profile_completeness,
        "createdAt": _iso(row.created_at),
    }


def product_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "businessId": row.business_id,
        "name": row.name,
        "productImage": row.product_image or "",
        "description": row.description or "",
        "category": row.category,
        "industry": row.industry,
        "condition": row.condition,
        "unit": row.unit,
        "availableQuantity": row.available_quantity,
        "minimumOrderQuantity": row.minimum_order_quantity,
        "indicativePrice": float(row.indicative_price or 0),
        "currency": row.currency,
        "countryOfOrigin": row.country_of_origin or "",
        "deliveryLocations": list(row.delivery_locations or []),
        "availabilityStatus": row.availability_status,
        "listingStatus": row.listing_status,
        "publishedAt": _iso(row.published_at),
        "views": row.views,
        "savedCount": row.saved_count,
    }


def buying_request_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "buyerBusinessId": row.buyer_business_id,
        "productOrService": row.product_or_service,
        "description": row.description or "",
        "category": row.category,
        "requiredQuantity": row.required_quantity,
        "unit": row.unit,
        "targetPriceRange": row.target_price_range or "",
        "currency": row.currency,
        "deliveryDestination": row.delivery_destination or "",
        "preferredSupplierLocation": row.preferred_supplier_location or "",
        "deadline": _iso(row.deadline),
        "urgency": row.urgency,
        "status": row.status,
        "publishedAt": _iso(row.published_at),
    }


def connection_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "requestingBusinessId": row.requesting_business_id,
        "receivingBusinessId": row.receiving_business_id,
        "status": str(row.status),
        "requestDate": _iso(row.request_date),
        "relationshipType": row.relationship_type,
        "introductoryMessage": row.introductory_message,
    }


def verification_to_api(row: Any) -> dict[str, Any]:
    return {
        "businessId": row.business_id,
        "status": _VERIFICATION_API.get(str(row.status), str(row.status)),
        "reviewMessage": row.review_message or "",
        "lastUpdated": _iso(row.last_updated),
    }


def message_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "senderId": row.sender_id,
        "text": row.body,
        "timestamp": _iso(row.created_at),
        "messageType": str(row.message_type),
        "readStatus": str(row.read_status),
        "attachmentName": row.attachment_name,
        "voiceDuration": row.voice_duration,
    }


def conversation_to_api(row: Any) -> dict[str, Any]:
    participants = [p.profile_id for p in (row.participants or [])]
    messages = sorted(row.messages or [], key=lambda m: m.created_at)
    return {
        "id": row.id,
        "participants": participants,
        "businessRelationship": row.business_relationship,
        "messages": [message_to_api(m) for m in messages],
    }


def notification_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "type": row.type,
        "title": row.title,
        "description": row.description or "",
        "timestamp": _iso(row.created_at),
        "read": row.is_read,
        "recipientId": row.recipient_id,
        "destination": row.destination,
    }


def feed_item_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "type": row.type,
        "sourceBusinessId": row.source_business_id or "",
        "title": row.title,
        "summary": row.summary or "",
        "timestamp": _iso(row.created_at),
        "relevanceExplanation": row.relevance_explanation or "",
        "actionMetadata": dict(row.action_metadata or {}),
    }


def analytics_to_api(row: Any) -> dict[str, Any]:
    return {
        "metric": row.metric,
        "value": float(row.value or 0),
        "delta": float(row.delta or 0),
        "period": row.period,
        "unit": row.unit,
    }


def category_to_api(row: Any) -> dict[str, Any]:
    return {
        "id": row.id,
        "name": row.name,
        "industry": row.industry,
        "description": row.description or "",
    }
