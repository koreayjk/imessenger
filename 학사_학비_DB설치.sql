-- =====================================================================
--  TCS 학사관리 — 학비/납부 관리 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.tuition_bills (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  title         text not null,            -- 항목명 (예: 2026-03 수업료)
  period        text,                     -- 청구 월 (YYYY-MM)
  amount        numeric not null default 0,
  due_date      date,                     -- 납부 기한
  paid          boolean not null default false,
  paid_date     date,                     -- 납부일
  paid_amount   numeric,                  -- 실 납부액
  method        text,                     -- 납부 방법 (현금/계좌/카드)
  note          text,
  created_by    uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_tuition_comm_period
  on public.tuition_bills (community_id, period);
create index if not exists idx_tuition_student
  on public.tuition_bills (student_id);

-- RLS — 로그인 사용자 접근 허용 (소규모 학교 내부용)
alter table public.tuition_bills enable row level security;

drop policy if exists tuition_bills_rw on public.tuition_bills;
create policy tuition_bills_rw on public.tuition_bills
  for all to authenticated
  using (true) with check (true);
