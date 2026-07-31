-- =====================================================================
--  TCS 예치금(학교가 맡아두는 돈) — 관리자 입금/출금 기록, 학생은 조회
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.deposit_entries (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  date          date not null,
  type          text not null,            -- 'in'(입금) | 'out'(출금)
  amount        numeric not null default 0,
  currency      text not null default '원',   -- '원' | '$'
  memo          text,
  created_by    uuid,
  created_at    timestamptz default now()
);
create index if not exists idx_deposit_member_date on public.deposit_entries (member_id, date desc);

alter table public.deposit_entries enable row level security;
drop policy if exists deposit_select on public.deposit_entries;
drop policy if exists deposit_insert on public.deposit_entries;
drop policy if exists deposit_update on public.deposit_entries;
drop policy if exists deposit_delete on public.deposit_entries;

-- 조회: 본인 + 담당교사(단일/다중) + 관리자
create policy deposit_select on public.deposit_entries for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = deposit_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);
-- 기록/수정/삭제: 담당교사·관리자·교직원만 (학생 본인은 조회만)
create policy deposit_insert on public.deposit_entries for insert to authenticated
with check (
  exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = deposit_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);
create policy deposit_update on public.deposit_entries for update to authenticated
using (
  exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = deposit_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);
create policy deposit_delete on public.deposit_entries for delete to authenticated
using (
  exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = deposit_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);

NOTIFY pgrst, 'reload schema';
