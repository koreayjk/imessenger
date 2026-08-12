-- =====================================================================
--  재정 권한 복구: 관리자·행정담당·교사·간사가 용돈/예치금을 기록 못 하는 문제
--  원인: RLS가 영문 community_role만 확인 → 한글 role만 설정된 관리자는 막힘
--  해결: community_role 또는 한글 role 중 하나라도 교직원이면 허용
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- 교직원(기록 권한) 판별 헬퍼 — 영문/한글 역할 모두 인정, 이메일 총관리자도 포함
create or replace function public.is_finance_staff()
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

-- ── 용돈(allowance_entries) ──
drop policy if exists allowance_insert on public.allowance_entries;
drop policy if exists allowance_update on public.allowance_entries;
drop policy if exists allowance_delete on public.allowance_entries;
create policy allowance_insert on public.allowance_entries for insert to authenticated
  with check ( member_id = auth.uid()
    or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
    or public.is_finance_staff() );
create policy allowance_update on public.allowance_entries for update to authenticated
  using ( member_id = auth.uid()
    or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
    or public.is_finance_staff() );
create policy allowance_delete on public.allowance_entries for delete to authenticated
  using ( member_id = auth.uid()
    or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
    or public.is_finance_staff() );

-- ── 예치금(deposit_entries) ──
drop policy if exists deposit_insert on public.deposit_entries;
drop policy if exists deposit_update on public.deposit_entries;
drop policy if exists deposit_delete on public.deposit_entries;
create policy deposit_insert on public.deposit_entries for insert to authenticated
  with check ( public.is_finance_staff()
    or exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid()) );
create policy deposit_update on public.deposit_entries for update to authenticated
  using ( public.is_finance_staff()
    or exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid()) );
create policy deposit_delete on public.deposit_entries for delete to authenticated
  using ( public.is_finance_staff()
    or exists (select 1 from public.members s where s.id = deposit_entries.member_id and s.homeroom_teacher_id = auth.uid()) );

NOTIFY pgrst, 'reload schema';
