# Supabase database setup

TradeSquare marketplace data lives in **PostgreSQL on Supabase**. The Flutter app no longer ships sample catalogs; it loads `/api/v1/catalog/bootstrap` from the FastAPI backend, which reads the same database.

## 1. Create a Supabase project

1. Open [supabase.com](https://supabase.com) and create a project.
2. In **Project Settings → Database**, copy the **URI** connection string.
3. Put it in `.env` as `DATABASE_URL` (prefer the pooled URI for the API):

```bash
DATABASE_URL=postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
```

The backend normalizes `postgres://` / `postgresql://` to `postgresql+psycopg://`.

Flutter Auth uses the public URL + anon (publishable) key. Keep the service role on the server only:

```bash
SUPABASE_URL=https://[ref].supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # server only — never ship to the app
```

## 2. Apply schema + seed

In the Supabase **SQL Editor**, run in order:

1. [`supabase/migrations/20261113000000_init_schema.sql`](../../supabase/migrations/20261113000000_init_schema.sql)
2. [`supabase/migrations/20261113010000_auth_profiles.sql`](../../supabase/migrations/20261113010000_auth_profiles.sql) — Auth → `profiles` trigger, `account_intent`, profile update RLS
3. [`supabase/seed.sql`](../../supabase/seed.sql)

Or with the CLI:

```bash
supabase db push
psql "$DATABASE_URL" -f supabase/seed.sql
```

Local Docker (optional):

```bash
docker compose up -d
# then apply the same SQL files against localhost:5432
```

## 3. Run the API

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

Check:

- `GET http://localhost:8000/api/v1/catalog/health`
- `GET http://localhost:8000/api/v1/catalog/bootstrap`

## 4. Flutter

Defaults in `AppConfig` already point at the project URL/anon key. Override when needed:

```bash
flutter run -d chrome ^
  --dart-define=TRADESQUARE_API_BASE_URL=http://127.0.0.1:8000 ^
  --dart-define=SUPABASE_URL=https://[ref].supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Login/register use Supabase Auth. Role comes from `profiles.account_intent` / `profiles.role` after sign-in (not from a login-screen picker). In **Authentication → Providers**, enable Email. If email confirmation is on, new users must confirm before a session is issued.

(`10.0.2.2` is the Android emulator host loopback; use your LAN IP for a physical device.)

## Tables

| Table | Purpose |
|-------|---------|
| `profiles` | Users / accounts |
| `businesses` | Company profiles |
| `product_listings` | Sell-side listings |
| `buying_requests` | Buy-side RFQs |
| `business_connections` | Network graph |
| `conversations` / `messages` | Messaging |
| `notifications`, `feed_items`, `categories`, … | Supporting catalog |

RLS is enabled with public **read** policies for marketplace discovery. Authenticated users can **update** their own `profiles` row via `auth.uid() = auth_user_id`.
