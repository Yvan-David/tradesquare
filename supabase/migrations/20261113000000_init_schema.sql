-- TradeSquare marketplace schema for Supabase (PostgreSQL).
-- Apply in Supabase SQL editor or: supabase db push / psql $DATABASE_URL -f ...

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type user_role as enum (
    'business_owner', 'buyer', 'supplier', 'administrator'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type user_status as enum ('active', 'pending', 'inactive');
exception when duplicate_object then null; end $$;

do $$ begin
  create type verification_status as enum (
    'not_submitted',
    'submitted',
    'under_review',
    'additional_information_required',
    'approved',
    'rejected'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type connection_status as enum (
    'pending', 'accepted', 'rejected', 'blocked'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type message_type as enum (
    'text', 'attachment', 'voice', 'image'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type read_status as enum ('read', 'unread');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Core tables
-- ---------------------------------------------------------------------------
create table if not exists profiles (
  id text primary key,
  full_name text not null,
  email text not null unique,
  phone text,
  country text,
  city text,
  preferred_language text not null default 'en',
  role user_role not null default 'business_owner',
  status user_status not null default 'pending',
  business_id text,
  join_date timestamptz not null default now(),
  profile_completeness int not null default 0 check (profile_completeness between 0 and 100),
  photo_url text,
  auth_user_id uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists businesses (
  id text primary key,
  name text not null,
  logo_url text,
  description text not null default '',
  industry text not null,
  category text not null,
  country text not null,
  province text,
  city text not null,
  address text,
  email text,
  phone text,
  website text,
  registration_number text,
  registration_certificate_type text,
  certificate_submission_status text,
  verification_status verification_status not null default 'not_submitted',
  business_size text,
  year_established int,
  products_offered text[] not null default '{}',
  products_needed text[] not null default '{}',
  business_interests text[] not null default '{}',
  preferred_markets text[] not null default '{}',
  owner_id text references profiles(id) on delete set null,
  profile_completeness int not null default 0 check (profile_completeness between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles
  drop constraint if exists profiles_business_id_fkey;
alter table profiles
  add constraint profiles_business_id_fkey
  foreign key (business_id) references businesses(id) on delete set null;

create table if not exists categories (
  id text primary key,
  name text not null,
  industry text not null,
  description text not null default ''
);

create table if not exists product_listings (
  id text primary key,
  business_id text not null references businesses(id) on delete cascade,
  name text not null,
  product_image text,
  description text not null default '',
  category text not null,
  industry text not null,
  condition text not null default 'New',
  unit text not null default 'kg',
  available_quantity int not null default 0,
  minimum_order_quantity int not null default 0,
  indicative_price numeric(14, 2) not null default 0,
  currency text not null default 'USD',
  country_of_origin text,
  delivery_locations text[] not null default '{}',
  availability_status text not null default 'In stock',
  listing_status text not null default 'Active',
  published_at timestamptz not null default now(),
  views int not null default 0,
  saved_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists buying_requests (
  id text primary key,
  buyer_business_id text not null references businesses(id) on delete cascade,
  product_or_service text not null,
  description text not null default '',
  category text not null,
  required_quantity int not null default 0,
  unit text not null default 'kg',
  target_price_range text,
  currency text not null default 'USD',
  delivery_destination text,
  preferred_supplier_location text,
  deadline timestamptz,
  urgency text not null default 'Medium',
  status text not null default 'Open',
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists business_connections (
  id text primary key,
  requesting_business_id text not null references businesses(id) on delete cascade,
  receiving_business_id text not null references businesses(id) on delete cascade,
  status connection_status not null default 'pending',
  request_date timestamptz not null default now(),
  relationship_type text not null default 'supplier',
  introductory_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requesting_business_id, receiving_business_id)
);

create table if not exists business_verifications (
  business_id text primary key references businesses(id) on delete cascade,
  status verification_status not null default 'not_submitted',
  review_message text not null default '',
  last_updated timestamptz not null default now()
);

create table if not exists conversations (
  id text primary key,
  business_relationship text not null default 'supplier',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists conversation_participants (
  conversation_id text not null references conversations(id) on delete cascade,
  profile_id text not null references profiles(id) on delete cascade,
  primary key (conversation_id, profile_id)
);

create table if not exists messages (
  id text primary key,
  conversation_id text not null references conversations(id) on delete cascade,
  sender_id text not null references profiles(id) on delete cascade,
  body text not null default '',
  message_type message_type not null default 'text',
  read_status read_status not null default 'unread',
  attachment_name text,
  voice_duration text,
  created_at timestamptz not null default now()
);

create table if not exists notifications (
  id text primary key,
  type text not null,
  title text not null,
  description text not null default '',
  created_at timestamptz not null default now(),
  is_read boolean not null default false,
  recipient_id text not null references profiles(id) on delete cascade,
  destination text not null default '/messages'
);

create table if not exists feed_items (
  id text primary key,
  type text not null,
  source_business_id text references businesses(id) on delete set null,
  title text not null,
  summary text not null default '',
  created_at timestamptz not null default now(),
  relevance_explanation text not null default '',
  action_metadata jsonb not null default '{}'::jsonb
);

create table if not exists analytics_summaries (
  id bigserial primary key,
  business_id text references businesses(id) on delete cascade,
  metric text not null,
  value numeric not null default 0,
  delta numeric not null default 0,
  period text not null default '30d',
  unit text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists ai_recommendations (
  id text primary key,
  recommendation_type text not null,
  target_business_id text references businesses(id) on delete cascade,
  target_listing_id text references product_listings(id) on delete set null,
  explanation text not null default '',
  matching_factors text[] not null default '{}',
  relevance_score numeric not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists market_insights (
  id text primary key,
  industry text not null,
  title text not null,
  summary text not null default '',
  region text,
  metric_label text,
  value text,
  currency text,
  insight_date date,
  source text,
  is_illustrative boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists document_uploads (
  id text primary key,
  business_id text references businesses(id) on delete cascade,
  profile_id text references profiles(id) on delete set null,
  file_name text not null,
  file_type text,
  file_size bigint,
  upload_progress numeric not null default 0,
  upload_status text not null default 'pending',
  submission_date timestamptz not null default now(),
  review_status text,
  review_message text
);

create table if not exists interest_options (
  id serial primary key,
  label text not null unique
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_businesses_industry on businesses (industry);
create index if not exists idx_businesses_country on businesses (country);
create index if not exists idx_businesses_verification on businesses (verification_status);
create index if not exists idx_products_business on product_listings (business_id);
create index if not exists idx_products_status on product_listings (listing_status);
create index if not exists idx_requests_buyer on buying_requests (buyer_business_id);
create index if not exists idx_requests_status on buying_requests (status);
create index if not exists idx_messages_conversation on messages (conversation_id, created_at);
create index if not exists idx_notifications_recipient on notifications (recipient_id, is_read);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated on profiles;
create trigger trg_profiles_updated
  before update on profiles
  for each row execute function set_updated_at();

drop trigger if exists trg_businesses_updated on businesses;
create trigger trg_businesses_updated
  before update on businesses
  for each row execute function set_updated_at();

drop trigger if exists trg_products_updated on product_listings;
create trigger trg_products_updated
  before update on product_listings
  for each row execute function set_updated_at();

drop trigger if exists trg_requests_updated on buying_requests;
create trigger trg_requests_updated
  before update on buying_requests
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security (Supabase). API service role bypasses RLS.
-- ---------------------------------------------------------------------------
alter table profiles enable row level security;
alter table businesses enable row level security;
alter table categories enable row level security;
alter table product_listings enable row level security;
alter table buying_requests enable row level security;
alter table business_connections enable row level security;
alter table business_verifications enable row level security;
alter table conversations enable row level security;
alter table conversation_participants enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
alter table feed_items enable row level security;
alter table analytics_summaries enable row level security;
alter table ai_recommendations enable row level security;
alter table market_insights enable row level security;
alter table document_uploads enable row level security;
alter table interest_options enable row level security;

-- Public read for marketplace discovery (tighten later with auth.uid()).
create policy "Public read businesses"
  on businesses for select using (true);
create policy "Public read products"
  on product_listings for select using (true);
create policy "Public read buying requests"
  on buying_requests for select using (true);
create policy "Public read categories"
  on categories for select using (true);
create policy "Public read feed"
  on feed_items for select using (true);
create policy "Public read insights"
  on market_insights for select using (true);
create policy "Public read interests"
  on interest_options for select using (true);
create policy "Public read profiles"
  on profiles for select using (true);
create policy "Public read connections"
  on business_connections for select using (true);
create policy "Public read verifications"
  on business_verifications for select using (true);
create policy "Public read recommendations"
  on ai_recommendations for select using (true);
create policy "Public read analytics"
  on analytics_summaries for select using (true);

-- Authenticated users manage their own notifications / messages via service later.
create policy "Recipients read notifications"
  on notifications for select using (true);
create policy "Participants read conversations"
  on conversations for select using (true);
create policy "Participants read conversation members"
  on conversation_participants for select using (true);
create policy "Participants read messages"
  on messages for select using (true);
