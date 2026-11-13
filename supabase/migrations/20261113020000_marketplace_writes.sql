-- Allow marketplace writes via PostgREST (anon or service role).
-- Prefer SUPABASE_SERVICE_ROLE_KEY on the API; these policies keep anon writes working for MVP.

drop policy if exists "Public insert businesses" on businesses;
create policy "Public insert businesses"
  on businesses for insert
  with check (true);

drop policy if exists "Public update businesses" on businesses;
create policy "Public update businesses"
  on businesses for update
  using (true)
  with check (true);

drop policy if exists "Public insert buying requests" on buying_requests;
create policy "Public insert buying requests"
  on buying_requests for insert
  with check (true);

drop policy if exists "Public insert connections" on business_connections;
create policy "Public insert connections"
  on business_connections for insert
  with check (true);

drop policy if exists "Public update connections" on business_connections;
create policy "Public update connections"
  on business_connections for update
  using (true)
  with check (true);

drop policy if exists "Public update profiles" on profiles;
create policy "Public update profiles"
  on profiles for update
  using (true)
  with check (true);

drop policy if exists "Public insert conversations" on conversations;
create policy "Public insert conversations"
  on conversations for insert
  with check (true);

drop policy if exists "Public insert conversation members" on conversation_participants;
create policy "Public insert conversation members"
  on conversation_participants for insert
  with check (true);

drop policy if exists "Public insert messages" on messages;
create policy "Public insert messages"
  on messages for insert
  with check (true);

drop policy if exists "Public insert verifications" on business_verifications;
create policy "Public insert verifications"
  on business_verifications for insert
  with check (true);
