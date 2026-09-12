-- =====================================================================
--  학사 : 학생 개인 시간표를 교직원이 볼 수 있게
--   지금은 '본인 + 담당교사 + 관리자' 만 조회할 수 있어서,
--   간사(staff)와 담당이 아닌 교사(teacher)는 학생 시간표가 빈 칸으로 보입니다.
--   학사 페이지를 쓰는 교직원 전체가 볼 수 있도록 조회 정책만 넓힙니다.
--   (추가·수정·삭제는 그대로 '학생 본인만' — 교직원은 보기만 합니다)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- is_school_staff() : 총관리자 · 관리자 · 행정담당자 · 교사 · 간사
-- (이미 있으면 같은 내용으로 다시 만듭니다)
create or replace function public.is_school_staff()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff')
        or me.role in ('총관리자','관리자','행정담당자','교사','간사')
      )
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

-- 조회: 본인 + 담당교사(단일/다중) + 학사 교직원 전체
drop policy if exists stt_select on public.student_timetables;
create policy stt_select on public.student_timetables for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s
             where s.id = student_timetables.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h
             where h.student_id = student_timetables.member_id and h.teacher_id = auth.uid())
  or public.is_school_staff()
);

NOTIFY pgrst, 'reload schema';
