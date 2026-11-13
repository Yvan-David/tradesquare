-- New members become visible, can publish buying requests, and can connect.
-- Run in the Supabase SQL editor after the auth profiles migration.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id text := 'usr_' || replace(new.id::text, '-', '');
  biz_id text := 'biz_' || replace(new.id::text, '-', '');
  member_name text := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), split_part(new.email, '@', 1));
begin
  insert into public.profiles (
    id, full_name, email, phone, preferred_language, role, status,
    account_intent, auth_user_id, join_date, profile_completeness, business_id
  ) values (
    new_id,
    member_name,
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'preferred_language', 'en'),
    'business_owner',
    'active',
    coalesce(new.raw_user_meta_data->>'account_intent', 'both'),
    new.id,
    now(),
    40,
    biz_id
  )
  on conflict (email) do update
    set auth_user_id = excluded.auth_user_id,
        full_name = coalesce(nullif(excluded.full_name, ''), profiles.full_name),
        phone = coalesce(nullif(excluded.phone, ''), profiles.phone),
        status = 'active',
        updated_at = now();

  insert into public.businesses (
    id, name, description, industry, category, country, city,
    email, phone, owner_id, verification_status, profile_completeness
  ) values (
    biz_id,
    member_name,
    'New TradeSquare member',
    'General',
    'General',
    'Rwanda',
    'Kigali',
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', ''),
    new_id,
    'not_submitted',
    40
  )
  on conflict (id) do nothing;

  update public.profiles
    set business_id = biz_id
    where id = new_id and business_id is null;

  return new;
end;
$$;

-- Existing signed-up profiles that have no business yet.
insert into public.businesses (
  id, name, description, industry, category, country, city,
  email, phone, owner_id, verification_status, profile_completeness
)
select
  'biz_' || replace(p.id, 'usr_', ''),
  p.full_name,
  'TradeSquare member',
  'General',
  'General',
  coalesce(nullif(p.country, ''), 'Rwanda'),
  coalesce(nullif(p.city, ''), 'Kigali'),
  p.email,
  coalesce(p.phone, ''),
  p.id,
  'not_submitted',
  p.profile_completeness
from public.profiles p
where p.business_id is null
  and p.auth_user_id is not null
on conflict (id) do nothing;

update public.profiles p
set business_id = 'biz_' || replace(p.id, 'usr_', '')
where p.business_id is null
  and exists (
    select 1 from public.businesses b
    where b.id = 'biz_' || replace(p.id, 'usr_', '')
  );

drop policy if exists "Members insert own business" on businesses;
create policy "Members insert own business"
  on businesses for insert
  to authenticated
  with check (
    owner_id in (
      select id from profiles where auth_user_id = auth.uid()
    )
  );

drop policy if exists "Members update own business" on businesses;
create policy "Members update own business"
  on businesses for update
  to authenticated
  using (
    owner_id in (select id from profiles where auth_user_id = auth.uid())
  )
  with check (
    owner_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "Members insert buying requests" on buying_requests;
create policy "Members insert buying requests"
  on buying_requests for insert
  to authenticated
  with check (
    buyer_business_id in (
      select b.id from businesses b
      join profiles p on p.id = b.owner_id
      where p.auth_user_id = auth.uid()
    )
  );

drop policy if exists "Members insert connections" on business_connections;
create policy "Members insert connections"
  on business_connections for insert
  to authenticated
  with check (
    requesting_business_id in (
      select b.id from businesses b
      join profiles p on p.id = b.owner_id
      where p.auth_user_id = auth.uid()
    )
  );

drop policy if exists "Members update own connections" on business_connections;
create policy "Members update own connections"
  on business_connections for update
  to authenticated
  using (
    requesting_business_id in (
      select b.id from businesses b
      join profiles p on p.id = b.owner_id
      where p.auth_user_id = auth.uid()
    )
    or receiving_business_id in (
      select b.id from businesses b
      join profiles p on p.id = b.owner_id
      where p.auth_user_id = auth.uid()
    )
  )
  with check (true);
