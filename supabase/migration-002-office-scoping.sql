-- DocuRoute prototype — migration 002: per-office staff scoping
-- Run this ONCE in your EXISTING Supabase project's SQL Editor to bring it up
-- to date with the office-scoping changes now in schema.sql (Treasury renamed
-- from Accounting, Section Chief added as a 4th office), without losing any
-- existing accounts or request data. Safe to re-run — every statement is
-- idempotent (add-if-missing / drop-then-recreate).

-- =========================================================================
-- 1. profiles.office column + check constraint
-- =========================================================================

alter table public.profiles add column if not exists office text;

alter table public.profiles drop constraint if exists profiles_office_check;
alter table public.profiles add constraint profiles_office_check
  check (office in ('Registrar','Treasury','Section Chief','Dean''s Office'));

-- =========================================================================
-- 2. Helper functions
-- =========================================================================

create or replace function public.current_user_office()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select office from public.profiles where id = auth.uid();
$$;

grant execute on function public.current_user_office() to authenticated, anon;

create or replace function public.staff_can_see_request(req_route text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'admin'
      or (public.current_user_role() = 'staff' and public.current_user_office() = any(req_route));
$$;

grant execute on function public.staff_can_see_request(text[]) to authenticated, anon;

-- =========================================================================
-- 3. Replace the broad "any staff/admin" policies with office-scoped ones
-- =========================================================================

drop policy if exists "requests select own or staff/admin" on public.requests;
create policy "requests select own or office-scoped staff/admin"
  on public.requests for select
  using (student_id = auth.uid() or public.staff_can_see_request(route));

drop policy if exists "requests update by staff/admin" on public.requests;
create policy "requests update by office-scoped staff/admin"
  on public.requests for update
  using (public.staff_can_see_request(route))
  with check (public.staff_can_see_request(route));

-- insert policy is unchanged on purpose (any staff can capture a walk-in form
-- at intake regardless of office) — not dropped/recreated here.

drop policy if exists "logs select for visible requests" on public.request_logs;
create policy "logs select for visible requests"
  on public.request_logs for select
  using (exists (
    select 1 from public.requests r
    where r.id = request_logs.request_id
      and (r.student_id = auth.uid() or public.staff_can_see_request(r.route))
  ));

drop policy if exists "logs insert for visible requests" on public.request_logs;
create policy "logs insert for visible requests"
  on public.request_logs for insert
  with check (exists (
    select 1 from public.requests r
    where r.id = request_logs.request_id
      and (r.student_id = auth.uid() or public.staff_can_see_request(r.route))
  ));

drop policy if exists "documents insert for visible requests" on storage.objects;
create policy "documents insert for visible requests"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and exists (
      select 1 from public.requests r
      where r.id = (storage.foldername(name))[1]
        and (r.student_id = auth.uid() or public.staff_can_see_request(r.route))
    )
  );

drop policy if exists "documents read for visible requests" on storage.objects;
create policy "documents read for visible requests"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.requests r
      where r.id = (storage.foldername(name))[1]
        and (r.student_id = auth.uid() or public.staff_can_see_request(r.route))
    )
  );

-- =========================================================================
-- 4. Point your staff accounts at their office
-- =========================================================================
-- Run this part AFTER you've set each account's email/password in
-- Authentication -> Users (edit the existing "staff" user in place to become
-- "registrar" -- never delete and recreate it, see prototype.md warning #1,
-- or you'll wipe its profile and have to redo this).

update public.profiles set office='Registrar', name='Registrar Clerk'
  where email='registrar@mymail.mapua.edu.ph';
update public.profiles set role='staff', office='Treasury', name='Treasury Personnel'
  where email='treasury@mymail.mapua.edu.ph';
update public.profiles set role='staff', office='Section Chief', name='Section Chief'
  where email='prof@mymail.mapua.edu.ph';
update public.profiles set role='staff', office='Dean''s Office', name='Dean'
  where email='dean@mymail.mapua.edu.ph';

-- =========================================================================
-- 5. Reset the demo dataset so it picks up the corrected routes
-- =========================================================================
-- The four seed demo requests were created under the OLD routes (Accounting
-- instead of Treasury, Section Adjustment routed straight to Registrar with no
-- Section Chief step). Rather than hand-patch those rows' route[] arrays here,
-- just log in as Admin -> System Overview -> "Reset demo database" once after
-- running this migration -- it reseeds all four demo requests using the
-- current ROUTES in index.html, so they'll show up correctly in every queue.
