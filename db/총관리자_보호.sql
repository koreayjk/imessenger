-- =====================================================================
--  총관리자(super_admin) 보호 — 서버(RLS)에서 완전 차단
--  · 총관리자 권한 부여는 총관리자만
--  · 총관리자 멤버의 역할 변경·삭제는 총관리자만 (강등/탈퇴 방지)
--  UI 우회(브라우저 콘솔 직접 호출)까지 막습니다.
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================

-- 호출자가 총관리자인지 RLS 재귀 없이 확인하는 헬퍼
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.members
    where id = auth.uid() and community_role = 'super_admin'
  );
$$;

-- UPDATE 보호: 기존 행이 총관리자면 총관리자만 수정 / 결과 역할이 총관리자면 총관리자만 지정
drop policy if exists members_protect_superadmin_upd on public.members;
create policy members_protect_superadmin_upd on public.members
  as restrictive for update to authenticated
  using  ( community_role is distinct from 'super_admin' or public.is_super_admin() )
  with check ( community_role is distinct from 'super_admin' or public.is_super_admin() );

-- DELETE 보호: 총관리자 멤버는 총관리자만 삭제 가능
drop policy if exists members_protect_superadmin_del on public.members;
create policy members_protect_superadmin_del on public.members
  as restrictive for delete to authenticated
  using ( community_role is distinct from 'super_admin' or public.is_super_admin() );

NOTIFY pgrst, 'reload schema';
