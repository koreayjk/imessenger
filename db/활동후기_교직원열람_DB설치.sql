-- =====================================================================
--  ✍️ 활동후기·독후감 — 교직원이 읽는 권한을 '간사 이상' 으로 맞춥니다
--
--  무엇이 어긋나 있었나
--    "피드백은 간사 이상만 볼 수 있게" 라고 하셨는데, 실제 DB 는
--      · 본인
--      · 담임교사
--      · 총·부총관리자 · 관리자 · 행정담당자
--    만 읽게 되어 있었습니다. 즉 **담임이 아닌 교사·간사는 아예 못 읽습니다.**
--    말씀보다 좁습니다.
--
--    반대로 관리자·행정담당자는 **공동체 구분 없이** 열려 있었습니다.
--    남의 공동체 학생 글도 읽을 수 있었다는 뜻입니다. 이건 넓습니다.
--
--  이 파일이 하는 일
--    · 교사·간사·행정담당자·관리자 → **자기 공동체 안에서만** 읽습니다
--    · 담임은 전처럼 자기 반 학생
--    · 총·부총관리자는 공동체를 넘어 읽습니다 (읽기만. 고치지는 못합니다)
--    · 학생은 자기 글만. **학생끼리 서로 못 봅니다. 학부모도 못 봅니다.**
--
--  ※ 좁히고 싶으시면(예: 담임과 관리자급만) 아래 목록에서
--    'teacher','staff' 를 빼고 다시 돌리시면 됩니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

drop policy if exists writings_select on public.student_writings;
create policy writings_select on public.student_writings
  for select to authenticated
  using (
    member_id = (select auth.uid())
    or exists (select 1 from public.members s
                where s.id = student_writings.member_id
                  and s.homeroom_teacher_id = (select auth.uid()))
    or exists (select 1 from public.student_homerooms h
                where h.student_id = student_writings.member_id
                  and h.teacher_id = (select auth.uid()))
    or exists (select 1 from public.members me
                where me.id = (select auth.uid())
                  and ( me.community_role in ('super_admin','vice_admin')
                     or ( me.community_id = student_writings.community_id
                          and me.community_role in ('community_admin','admin_officer','teacher','staff') ) ))
  );
