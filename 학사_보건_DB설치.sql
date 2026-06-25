-- =====================================================================
--  TCS 학사관리 — 보건·건강 기록 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.health_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  date          date,
  category      text,            -- 보건실 방문/투약/병결/예방접종/기타
  title         text,            -- 증상/제목
  content       text,            -- 조치 내용·특이사항
  author_name   text,
  created_by    uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_health_student
  on public.health_logs (community_id, student_id, date desc);

alter table public.health_logs enable row level security;
drop policy if exists health_logs_rw on public.health_logs;
create policy health_logs_rw on public.health_logs
  for all to authenticated using (true) with check (true);
