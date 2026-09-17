-- DocuRoute prototype — migration 003: allow requests.type to be null
-- Run this ONCE in your EXISTING Supabase project's SQL Editor. Fixes:
-- "null value in column 'type' of relation 'requests' violates not-null
-- constraint" when a student submits online.
--
-- Why: a student's document is genuinely unclassified until the AI pipeline
-- finishes (index.html's finishPipeline()) -- inserting it with type=null at
-- submission and only filling it in once classification succeeds is what
-- fixes the earlier bug where a random placeholder type silently stuck
-- forever if the real classifier never responded. That requires the column
-- to actually allow null. The existing CHECK constraint is untouched and
-- still rejects anything other than 'waiver'/'adjustment'/'clearance'/null
-- (a CHECK is satisfied, not violated, when the value being checked is
-- null -- only NOT NULL was blocking this).
--
-- Safe to re-run.

alter table public.requests alter column type drop not null;
