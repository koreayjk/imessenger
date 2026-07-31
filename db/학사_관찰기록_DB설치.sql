-- =====================================================================
--  TCS 학사관리 — 학생 관찰 누가기록 (생기부 종합의견의 재료)
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.observation_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  date          date,
  category      text,            -- 학습/태도/인성/교우관계/특기·재능/기타
  title         text,
  content       text,
  author_name   text,
  created_by    uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_observation_student
  on public.observation_logs (community_id, student_id, date desc);

alter table public.observation_logs enable row level security;
drop policy if exists observation_logs_rw on public.observation_logs;
create policy observation_logs_rw on public.observation_logs
  for all to authenticated using (true) with check (true);

NOTIFY pgrst, 'reload schema';
