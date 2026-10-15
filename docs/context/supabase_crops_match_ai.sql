-- SoilGood — allow ai_assessments.kind = crops_match (catalog AI scores)
-- Run in Supabase SQL Editor after supabase_crops_home_ai.sql.
-- Safe to re-run.

alter table public.ai_assessments
  drop constraint if exists ai_assessments_kind_check;

alter table public.ai_assessments
  add constraint ai_assessments_kind_check
  check (kind in ('home', 'analytics', 'crops', 'crops_match'));
