-- =====================================================================
--  💰 재정 → 🐷 용돈  : 교사·간사도 기록할 수 있게 권한 넓히기
--
--  왜 필요한가
--   운영관리 → 재정 안에서 용돈·예치금은 교사·간사도 쓸 수 있게 열었습니다.
--   그런데 예치금 정책에는 teacher·staff 가 들어 있는데 용돈에는 없어서,
--   교사가 화면은 봐도 저장을 누르면 조용히 실패합니다.
--   (게다가 용돈은 담임 판단을 옛 members.homeroom_teacher_id 한 칸으로만 해서,
--    담당교사를 여러 명 두는 student_homerooms 를 못 봅니다)
--
--  이 파일은 예치금과 같은 모양으로 용돈 정책을 다시 깝니다.
--   · 조회 : 학생 본인 + 담당교사(옛 컬럼·새 표 둘 다) + 교사·간사·행정담당·관리자
--   · 추가·수정 : 위와 같음 (선생님이 학생 지출을 대신 적어 줄 수 있어야 함)
--   · 삭제 : 학생 본인은 못 함 (삭제 '요청'만). 담당교사·교사·간사·관리자만.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.allowance_entries enable row level security;

drop policy if exists allowance_own    on public.allowance_entries;
drop policy if exists allowance_select on public.allowance_entries;
drop policy if exists allowance_insert on public.allowance_entries;
drop policy if exists allowance_update on public.allowance_entries;
drop policy if exists allowance_delete on public.allowance_entries;

-- 조회
create policy allowance_select on public.allowance_entries for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s
             where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h
             where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me
             where me.id = auth.uid()
               and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);

-- 추가
create policy allowance_insert on public.allowance_entries for insert to authenticated
with check (
  member_id = auth.uid()
  or exists (select 1 from public.members s
             where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h
             where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me
             where me.id = auth.uid()
               and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);

-- 수정
create policy allowance_update on public.allowance_entries for update to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s
             where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h
             where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me
             where me.id = auth.uid()
               and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);

-- 삭제 — 학생 본인은 빠진다 (학생은 '삭제 요청'만 하고 선생님이 승인)
create policy allowance_delete on public.allowance_entries for delete to authenticated
using (
  exists (select 1 from public.members s
          where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h
             where h.student_id = allowance_entries.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me
             where me.id = auth.uid()
               and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);

notify pgrst, 'reload schema';

-- =====================================================================
--  끝. 이제 교사·간사도 운영관리 → 재정 → 🐷 용돈 / 🏦 예치금 을 쓸 수 있습니다.
--  (💰 학비 와 📒 입출금 은 그대로 행정담당·관리자만 보입니다)
-- =====================================================================
