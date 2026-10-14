-- DocuRoute prototype — migration 007: Registrar can see unclassified requests
-- Run this ONCE in your EXISTING Supabase project's SQL Editor.
--
-- Problem: when the AI isn't confident (< 70%) a student's request is saved
-- with type = null and route = '{}' (the route is only filled in once a type
-- is known). staff_can_see_request() lets a staff account see a request only
-- if its own office appears in the route, and an empty route contains no
-- office -- so the Registrar, whose job is exactly to confirm these, saw
-- nothing, even though the app showed the student "Registrar will confirm".
--
-- Fix: the Registrar's office may also see (and update) requests whose route
-- is still empty. Once the Registrar confirms a type the route is set and the
-- normal rule applies again. Other offices are unaffected.
--
-- (Numbering note: migration-006 is referenced in older notes as a student
-- write-back migration but is not in this repo, so this one is 007. This
-- file only replaces one function, so it is safe to run in any order and
-- safe to re-run.)

create or replace function public.staff_can_see_request(req_route text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'admin'
      or (public.current_user_role() = 'staff' and (
            public.current_user_office() = any(req_route)
            or (public.current_user_office() = 'Registrar' and coalesce(cardinality(req_route), 0) = 0)
         ));
$$;

grant execute on function public.staff_can_see_request(text[]) to authenticated, anon;
