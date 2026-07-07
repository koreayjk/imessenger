-- =====================================================================
--  TCS 학사관리 — 전자결재(출결 신청 → 승인 → 출석부 자동 반영)
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.leave_requests (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  student_name  text,
  type          text,                 -- 결석/지각/조퇴/외출/체험학습/병결/기타
  att_status    text,                 -- 출석부 반영값: absent/late/early/excused/sick
  start_date    date,
  end_date      date,
  reason        text,
  status        text default 'pending',   -- pending / approved / rejected
  decided_by    uuid,
  decider_name  text,
  decided_at    timestamptz,
  decision_note text,
  created_by    uuid,
  created_at    timestamptz default now()
);

create index if not exists idx_leave_comm_status
  on public.leave_requests (community_id, status, created_at desc);
create index if not exists idx_leave_student
  on public.leave_requests (student_id, created_at desc);

alter table public.leave_requests enable row level security;
drop policy if exists leave_requests_rw on public.leave_requests;
create policy leave_requests_rw on public.leave_requests
  for all to authenticated using (true) with check (true);

NOTIFY pgrst, 'reload schema';
