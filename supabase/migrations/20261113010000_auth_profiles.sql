-- Link Supabase Auth users to marketplace profiles.
-- Run in SQL editor after the init schema.

alter table profiles
  add column if not exists account_intent text
    check (account_intent is null or account_intent in ('buyer', 'supplier', 'both'));

create index if not exists idx_profiles_auth_user_id on profiles (auth_user_id);

-- New auth user → profile row (role/intent defaults; onboarding can refine).
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id text := 'usr_' || replace(new.id::text, '-', '');
begin
  insert into public.profiles (
    id,
    full_name,
    email,
    phone,
    preferred_language,
    role,
    status,
    account_intent,
    auth_user_id,
    join_date,
    profile_completeness
  ) values (
    new_id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'preferred_language', 'en'),
    'business_owner',
    'pending',
    coalesce(new.raw_user_meta_data->>'account_intent', 'both'),
    new.id,
    now(),
    20
  )
  on conflict (email) do update
    set auth_user_id = excluded.auth_user_id,
        full_name = coalesce(nullif(excluded.full_name, ''), profiles.full_name),
        phone = coalesce(nullif(excluded.phone, ''), profiles.phone),
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Authenticated users can update their own profile (public read already exists).
drop policy if exists "Users read own profile" on profiles;

drop policy if exists "Users update own profile" on profiles;
create policy "Users update own profile"
  on profiles for update
  to authenticated
  using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);

drop policy if exists "Users insert own profile" on profiles;
create policy "Users insert own profile"
  on profiles for insert
  to authenticated
  with check (auth.uid() = auth_user_id);
