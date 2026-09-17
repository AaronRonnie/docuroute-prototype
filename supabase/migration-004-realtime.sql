-- DocuRoute prototype — migration 004: enable Realtime on requests/request_logs
-- Run this ONCE in your EXISTING Supabase project's SQL Editor.
--
-- Why: without a table in the `supabase_realtime` publication, Supabase never
-- broadcasts row changes for it, so every open tab/account only ever saw the
-- current state at its last manual reload -- one account consenting/clearing
-- a request was invisible to every other open tab until it refreshed. Adding
-- the table here is what lets index.html's subscribeRealtime() actually
-- receive change events. Realtime still respects each subscriber's own RLS
-- policies -- this does not expose anything a tab couldn't already SELECT.
--
-- Safe to re-run (guarded against "already a member of publication").

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'requests'
  ) then
    alter publication supabase_realtime add table public.requests;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'request_logs'
  ) then
    alter publication supabase_realtime add table public.request_logs;
  end if;
end $$;
