-- =====================================================================
--  총관리자(super_admin) 복구 — koreayjk@gmail.com
--  Supabase → SQL Editor 에서 실행하세요.
--  (앱은 이 이메일을 항상 총관리자로 인식하지만, DB 권한(RLS)까지
--   확실히 맞추려면 아래를 한 번 실행해 두는 것이 좋습니다.)
-- =====================================================================

update public.members
set community_role = 'super_admin'
where lower(email) = 'koreayjk@gmail.com';

-- 확인
select id, name, email, community_role from public.members
where lower(email) = 'koreayjk@gmail.com';
