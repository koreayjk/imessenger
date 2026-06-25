-- =====================================================================
--  TCS 학사관리 — 주간 시간표 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.timetables (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  group_id      uuid,             -- 반(student_groups.id). null = 공통(전체) 시간표
  day           int  not null,    -- 1=월 ~ 5=금
  period        int  not null,    -- 교시 (1,2,3...)
  subject       text,             -- 과목
  teacher       text,             -- 담당 교사
  room          text,             -- 교실
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_timetables_comm_group
  on public.timetables (community_id, group_id);

-- RLS — 로그인 사용자 접근 허용 (소규모 학교 내부용)
alter table public.timetables enable row level security;

drop policy if exists timetables_rw on public.timetables;
create policy timetables_rw on public.timetables
  for all to authenticated
  using (true) with check (true);
