-- DocuRoute prototype — migration 005: recognize 3 more document types
-- Run this ONCE in your EXISTING Supabase project's SQL Editor.
--
-- Adds Course Completion, Transferee Crediting, and Shift Program/Modality
-- as routable types alongside the original 3 (Prerequisite Waiver, Section
-- Adjustment, Student Clearance) -- see ai-classifier/README.md and
-- prototype/index.html's ROUTES/TYPE_LABEL for the matching classifier and
-- routing-table changes this pairs with. requests.type is nullable (from
-- migration-003), so this only widens the CHECK constraint's allowed values.
--
-- Safe to re-run.

alter table public.requests drop constraint if exists requests_type_check;
alter table public.requests add constraint requests_type_check
  check (type in ('waiver','adjustment','clearance','course_completion','crediting','shift_program'));
