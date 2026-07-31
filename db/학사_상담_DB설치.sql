-- =====================================================================
--  TCS 학사관리 — 상담·생활지도 기록 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.counseling_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  date          date,
  category      text,            -- 상담/생활지도/칭찬/주의/기타
  title         text,
  content       text,
  author_name   text,
  created_by    uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_counseling_student
  on public.counseling_logs (community_id, student_id, date desc);

alter table public.counseling_logs enable row level security;
drop policy if exists counseling_logs_rw on public.counseling_logs;
create policy counseling_logs_rw on public.counseling_logs
  for all to authenticated using (true) with check (true);
