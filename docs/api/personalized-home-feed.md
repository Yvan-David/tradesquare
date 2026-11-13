# Personalized Home Feed API Contract

**Status:** Proposed. No corresponding backend endpoints or marketplace data
sources currently exist.

The authenticated Home screen consumes real data through a
`TradeSquareHomeFeedRepository`. The Flutter feature defines the client-side
contract; the backend must authorize the user and apply access controls before
returning any business information. Until these endpoints are implemented, the
screen must receive data and actions from its host and must not substitute
sample businesses, requests, market statistics, or recommendation counts.

## Endpoints

All paths below are proposed under `/api/v1`. Responses are JSON. Requests
require the application's normal authenticated session.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/home/feed?limit=20&cursor=...` | Return ordered feed sections and the next opaque cursor. |
| `GET` | `/home/recommendations/buyers?limit=20&cursor=...` | Buyers compatible with the user's offered products and goals. |
| `GET` | `/home/recommendations/suppliers?limit=20&cursor=...` | Suppliers compatible with the user's needs and goals. |
| `GET` | `/home/recommendations/products?limit=20&cursor=...` | Relevant active product listings. |
| `GET` | `/home/buying-requests?relevant=true&limit=20&cursor=...` | Active buying requests relevant to the user's business. |
| `PUT` | `/users/me/business-interests` | Validate and update the authenticated user's interests. |
| `POST` | `/home/interactions` | Record a meaningful, authorized recommendation interaction. |
| `POST` | `/home/feedback` | Record explicit recommendation feedback. |
| `GET` | `/home/recommendations/{opportunity_id}/explanation` | Return user-safe reasons for a recommendation. |

Endpoints that are not implemented must not be called or represented by a
successful fallback response.

The existing authenticated top bar remains the single global text-search
entrypoint. Optional image-search and voice-search controls are exposed only
when the host supplies callbacks; the current workspace has no media picker,
speech-recognition, or search-result service. The host must obtain appropriate
permissions and user consent before processing image or voice input.

## Feed response

```json
{
  "sections": [
    {
      "type": "buyers",
      "items": [
        {
          "id": "opaque-resource-id",
          "type": "buyer_request",
          "title": "Resource title",
          "summary": "Public marketplace description",
          "business_name": "Authorized public business name",
          "category": "Category",
          "industry": "Industry",
          "location": "Location",
          "keywords": ["requested product"],
          "image_url": null,
          "created_at": "2026-01-01T00:00:00Z",
          "expires_at": null,
          "status": "active",
          "is_verified": false,
          "recommendation_reasons": ["product_match", "location_match"]
        }
      ]
    }
  ],
  "next_cursor": null
}
```

The example values illustrate field shapes only; they are not seed records.
`is_verified` must come from the authoritative verification source. Omit
expired, unavailable, unauthorized, or otherwise non-public content. Include
only recommendation reason codes supported by a transparent ranking signal.
Cursor values are opaque, and the server must enforce a bounded page size.

## Interests and feedback

`PUT /users/me/business-interests` accepts a validated list of interest IDs or
canonical labels and returns the saved preferences. A client must not submit
changes for another user.

`POST /home/interactions` accepts an opportunity ID, an allow-listed event type
(`viewed`, `saved`, `contacted`, `connected`,
`requested_more_like_this`, or `marked_not_interested`), and an event/request
identifier for idempotency. Do not send sensitive profile fields or full search
text in analytics events unless separately authorized and privacy-reviewed.

`POST /home/feedback` accepts the opportunity ID and explicit feedback
(`more_like_this` or `not_interested`). A save uses the marketplace's
authoritative save operation; it should not be treated as a successful save
until that operation succeeds.

The explanation endpoint returns reason codes and optional concise
user-displayable explanation text. It must not expose another business's
confidential profile data or internal ranking features.

## Ranking and trust requirements

The initial ranking can use transparent, configurable rules for business
category, industry, offered/needed products, explicit interests, location or
target markets, commercial intent, and freshness. Product and service
compatibility may produce relevant cross-industry recommendations; do not
filter exclusively by industry. Exclude duplicate, expired, unavailable,
suppressed, or unauthorized opportunities. Explicit saves, contact requests,
buying requests, and user feedback may carry more weight than passive views.

The Flutter `RuleBasedTradeSquareFeedRanker` is a deterministic domain-level
fallback for already authorized candidate data. It uses exact normalized
terms rather than semantic inference. Its relative relevance value is not a
probability of a successful transaction. The backend remains responsible for
candidate authorization, pagination, persistent preferences, behavioral
signals, privacy controls, and production ranking. Do not claim ML ranking
until a model is trained, evaluated, deployed, and monitored.
