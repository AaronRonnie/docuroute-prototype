-- DocuRoute prototype — Supabase schema
-- Run this once in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query -> Run).
-- Requires: a Supabase project on the free tier. No extensions need enabling manually.

-- =========================================================================
-- PROFILES (role, name, and the fields the app needs alongside auth.users)
-- =========================================================================

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  role text not null default 'student' check (role in ('student','staff','admin')),
  name text not null default '',
  student_no text,
  program text,
  created_at timestamptz not null default now()
);

-- Auto-create a blank profile row whenever someone signs up in auth.users.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'name', new.email));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Security-definer helper so policies can check role without recursive RLS.
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

grant execute on function public.current_user_role() to authenticated, anon;

alter table public.profiles enable row level security;

create policy "profiles select own or staff/admin"
  on public.profiles for select
  using (auth.uid() = id or public.current_user_role() in ('staff','admin'));

create policy "profiles update by owner or admin"
  on public.profiles for update
  using (auth.uid() = id or public.current_user_role() = 'admin')
  with check (auth.uid() = id or public.current_user_role() = 'admin');

-- A non-admin editing their own row can't hand themselves a new role.
create or replace function public.prevent_self_role_escalation()
returns trigger
language plpgsql
as $$
begin
  if new.role <> old.role and public.current_user_role() <> 'admin' then
    raise exception 'Only an admin can change a role.';
  end if;
  return new;
end;
$$;

create trigger trg_prevent_self_role_escalation
  before update on public.profiles
  for each row execute function public.prevent_self_role_escalation();

-- =========================================================================
-- REQUESTS + AUDIT LOG
-- =========================================================================

create sequence public.request_seq start 1;

create or replace function public.next_request_id()
returns text
language sql
security definer
as $$
  select 'DR-2026-' || lpad(nextval('public.request_seq')::text, 4, '0');
$$;

grant execute on function public.next_request_id() to authenticated;

-- Admin-only: restarts the demo ID counter, used by the "Reset demo database" button.
create or replace function public.reset_request_seq()
returns void
language plpgsql
security definer
as $$
begin
  if public.current_user_role() <> 'admin' then
    raise exception 'not authorized';
  end if;
  alter sequence public.request_seq restart with 1;
end;
$$;

grant execute on function public.reset_request_seq() to authenticated;

create table public.requests (
  id text primary key,
  type text not null check (type in ('waiver','adjustment','clearance')),
  student_id uuid references public.profiles(id),
  student_name text not null,
  student_no text,
  program text,
  contact_no text,
  fields jsonb not null default '{}'::jsonb,
  confidence int,
  route text[] not null,
  hop int not null default 0,
  status text not null default 'submitted',
  document_path text,
  created_at timestamptz not null default now()
);

create table public.request_logs (
  id bigserial primary key,
  request_id text not null references public.requests(id) on delete cascade,
  text text not null,
  ts timestamptz not null default now()
);

alter table public.requests enable row level security;
alter table public.request_logs enable row level security;

create policy "requests select own or staff/admin"
  on public.requests for select
  using (student_id = auth.uid() or public.current_user_role() in ('staff','admin'));

create policy "requests insert own or staff/admin"
  on public.requests for insert
  with check (student_id = auth.uid() or public.current_user_role() in ('staff','admin'));

create policy "requests update by staff/admin"
  on public.requests for update
  using (public.current_user_role() in ('staff','admin'))
  with check (public.current_user_role() in ('staff','admin'));

create policy "requests delete by admin"
  on public.requests for delete
  using (public.current_user_role() = 'admin');

create policy "logs select for visible requests"
  on public.request_logs for select
  using (exists (
    select 1 from public.requests r
    where r.id = request_logs.request_id
      and (r.student_id = auth.uid() or public.current_user_role() in ('staff','admin'))
  ));

create policy "logs insert for visible requests"
  on public.request_logs for insert
  with check (exists (
    select 1 from public.requests r
    where r.id = request_logs.request_id
      and (r.student_id = auth.uid() or public.current_user_role() in ('staff','admin'))
  ));

create policy "logs delete by admin"
  on public.request_logs for delete
  using (public.current_user_role() = 'admin');

-- =========================================================================
-- STORAGE (digital-twin archiving of the uploaded/photographed paper form)
-- =========================================================================

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- Files are stored at "<request-id>/<filename>" so the first path segment
-- ties an object back to the request row it belongs to.
create policy "documents insert for visible requests"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and exists (
      select 1 from public.requests r
      where r.id = (storage.foldername(name))[1]
        and (r.student_id = auth.uid() or public.current_user_role() in ('staff','admin'))
    )
  );

create policy "documents read for visible requests"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.requests r
      where r.id = (storage.foldername(name))[1]
        and (r.student_id = auth.uid() or public.current_user_role() in ('staff','admin'))
    )
  );

-- Without this, nobody (not even admin) can remove an uploaded file from the
-- app — found during debugging when a leftover test upload couldn't be cleaned up.
create policy "documents delete by admin"
  on storage.objects for delete
  using (bucket_id = 'documents' and public.current_user_role() = 'admin');

-- =========================================================================
-- NEXT STEPS (do these in the Supabase Dashboard, not in this SQL file)
-- =========================================================================
-- 1. Authentication -> Providers -> Email -> turn OFF "Confirm email"
--    (this prototype has no email server wired up to click confirmation links).
-- 2. Authentication -> Users -> Add user, create the three demo accounts below.
--    Each one gets a blank profiles row automatically via the trigger above.
-- 3. Run the UPDATE statements below (SQL Editor) to set their role/name/etc.
--    Swap in real UUIDs by copying them from Authentication -> Users, or run
--    this as-is if you created the users with these exact emails.

-- update public.profiles set role='student', name='Aaron Peter San Pedro',
--   student_no='2021100234', program='BS Information Technology / 4'
--   where email='apvsanpedro@mymail.mapua.edu.ph';
-- update public.profiles set role='staff', name='Staff Member'
--   where email='staff@mymail.mapua.edu.ph';
-- update public.profiles set role='admin', name='System Administrator'
--   where email='admin@mymail.mapua.edu.ph';
