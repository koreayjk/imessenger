-- =====================================================================
--  TCS 학사관리 — 일일 전자출석부 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.attendance_daily (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  date          date not null,
  -- present(출석) / late(지각) / early(조퇴) / absent(결석) / sick(병결) / excused(공결)
  status        text not null default 'present',
  note          text,
  recorded_by   uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  unique (student_id, date)
);

-- 조회 성능용 인덱스 (날짜·공동체 기준 조회가 잦음)
create index if not exists idx_attendance_daily_comm_date
  on public.attendance_daily (community_id, date);
create index if not exists idx_attendance_daily_student_date
  on public.attendance_daily (student_id, date);

-- =====================================================================
--  RLS (행 수준 보안)
--  내부용 소규모 학교 도구라 "로그인한 사용자"에게 접근을 허용합니다.
--  공동체별로 더 엄격히 막고 싶으면 아래 policy 의 using/with check 를
--  members 테이블과 조인하는 조건으로 바꾸세요.
-- =====================================================================
alter table public.attendance_daily enable row level security;

drop policy if exists attendance_daily_rw on public.attendance_daily;
create policy attendance_daily_rw on public.attendance_daily
  for all
  to authenticated
  using (true)
  with check (true);
