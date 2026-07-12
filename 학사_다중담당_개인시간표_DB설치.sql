-- =====================================================================
--  TCS 학사관리 — 다중 담당교사 + 학생 개인 시간표
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

-- ── 1) 다중 담당교사 (학생 ↔ 교사 다대다) ───────────────────────────
create table if not exists public.student_homerooms (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid,
  student_id   uuid not null references public.members(id) on delete cascade,
  teacher_id   uuid not null references public.members(id) on delete cascade,
  created_at   timestamptz default now(),
  unique (student_id, teacher_id)
);
create index if not exists idx_homerooms_student on public.student_homerooms (student_id);
create index if not exists idx_homerooms_teacher on public.student_homerooms (teacher_id);

alter table public.student_homerooms enable row level security;
drop policy if exists student_homerooms_rw on public.student_homerooms;
create policy student_homerooms_rw on public.student_homerooms
  for all to authenticated using (true) with check (true);

-- 기존 단일 담당교사(members.homeroom_teacher_id) 값을 junction 으로 이전
insert into public.student_homerooms (community_id, student_id, teacher_id)
select m.community_id, m.id, m.homeroom_teacher_id
from public.members m
where m.homeroom_teacher_id is not null
on conflict (student_id, teacher_id) do nothing;

-- ── 2) 학생 개인 시간표 (대학 수업 등) ──────────────────────────────
create table if not exists public.student_timetables (
  id           uuid primary key default gen_random_uuid(),
  member_id    uuid not null references public.members(id) on delete cascade,
  community_id uuid,
  day          int  not null,        -- 1=월 … 7=일
  start_time   text not null,        -- 'HH:MM'
  end_time     text not null,        -- 'HH:MM'
  subject      text,                 -- 과목/수업명
  place        text,                 -- 강의실/장소
  color        text,
  term         text,                 -- 학기: 'YYYY-spring|summer|fall'
  created_at   timestamptz default now()
);
-- 이미 있던 경우 학기 컬럼 보강
alter table public.student_timetables add column if not exists term text;
create index if not exists idx_stt_member on public.student_timetables (member_id, day);

alter table public.student_timetables enable row level security;
drop policy if exists stt_select on public.student_timetables;
drop policy if exists stt_insert on public.student_timetables;
drop policy if exists stt_update on public.student_timetables;
drop policy if exists stt_delete on public.student_timetables;

-- 조회: 본인 + 담당교사(단일/다중) + 관리자
create policy stt_select on public.student_timetables for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = student_timetables.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = student_timetables.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
-- 추가/수정/삭제: 본인만
create policy stt_insert on public.student_timetables for insert to authenticated with check (member_id = auth.uid());
create policy stt_update on public.student_timetables for update to authenticated using (member_id = auth.uid());
create policy stt_delete on public.student_timetables for delete to authenticated using (member_id = auth.uid());

-- ── 3) 기존 정책에 '다중 담당교사' 반영 (용돈 / 학생기록) ────────────
-- 용돈기입장
drop policy if exists allowance_select on public.allowance_entries;
create policy allowance_select on public.allowance_entries for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
drop policy if exists allowance_update on public.allowance_entries;
create policy allowance_update on public.allowance_entries for update to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
drop policy if exists allowance_insert on public.allowance_entries;
create policy allowance_insert on public.allowance_entries for insert to authenticated
with check (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
drop policy if exists allowance_delete on public.allowance_entries;
create policy allowance_delete on public.allowance_entries for delete to authenticated
using (
  exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

-- 학생 기록(독후감/활동후기)
drop policy if exists writings_select on public.student_writings;
create policy writings_select on public.student_writings for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = student_writings.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = student_writings.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

NOTIFY pgrst, 'reload schema';
