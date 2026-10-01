-- =====================================================================
--  👤 부총관리자 (vice_admin)
--
--  총관리자 바로 아래 직위.
--   · 모든 공동체를 넘나들며 볼 수 있다
--   · 채팅은 어디서나 할 수 있다
--   · 관리(승인·역할변경·탈퇴·설정)는 '자기 소속 공동체'에서만
--   · 공동체를 만들거나 지우거나 고치는 것은 할 수 없다 (총관리자만)
--
--  앱은 소속(members.community_id)을 그대로 두고 '보는 곳'만 따로 들고 다닙니다.
--  총관리자처럼 소속을 갈아끼우면 '내 공동체'가 따라다녀서
--  어디서나 관리자가 되어 버리기 때문입니다.
--  그래서 여기 정책도 members.community_id 를 '본거지'로 믿고 씁니다.
--
--  ※ db/멤버_개인정보_보호_RLS.sql 을 먼저 실행한 뒤에 돌려주세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 1. 헬퍼 ──
-- 공동체를 넘나들며 '볼 수' 있는 사람 (총관리자 + 부총관리자)
create or replace function public.can_view_all_communities()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','vice_admin'));
$$;
grant execute on function public.can_view_all_communities() to authenticated;

-- 멤버를 관리할 수 있는 사람. 부총관리자는 '자기 공동체 안에서만' 이라
-- 여기엔 넣지 않고, 아래 정책에서 공동체를 맞춰 본다.
create or replace function public.can_admin_members()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','community_admin'));
$$;
grant execute on function public.can_admin_members() to authenticated;

create or replace function public.is_vice_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid() and community_role = 'vice_admin');
$$;
grant execute on function public.is_vice_admin() to authenticated;


-- ── 2. 읽기 — 부총관리자도 모든 공동체를 본다 ──
drop policy if exists members_select on public.members;
create policy members_select on public.members
  for select to authenticated
  using (
    id = auth.uid()
    or public.can_view_all_communities()
    or community_id = public.my_community_id()
  );


-- ── 3. 고치기 — 부총관리자는 자기 공동체에서만 관리자 노릇 ──
--  남의 공동체 멤버는 역할도 상태도 못 바꾼다. 서버에서 막는다.
drop policy if exists members_update on public.members;
create policy members_update on public.members
  for update to authenticated
  using (
    id = auth.uid()
    or public.can_admin_members()
    or (public.is_vice_admin() and community_id = public.my_community_id())
    or community_id = public.my_community_id()
  )
  with check (
    public.can_admin_members()
    or (public.is_vice_admin() and community_id = public.my_community_id())
    or ( community_role is not distinct from public.member_role_of(id)
         and status     is not distinct from public.member_status_of(id) )
  );


-- ── 4. 지우기 — 자기 공동체 안에서만 ──
drop policy if exists members_delete on public.members;
create policy members_delete on public.members
  for delete to authenticated
  using (
    public.can_admin_members()
    or (public.is_vice_admin() and community_id = public.my_community_id())
  );


-- ── 5. 총관리자·부총관리자 자리는 총관리자만 건드린다 ──
--  부총관리자가 스스로를 총관리자로 올리거나, 다른 부총관리자를 내리지 못하게.
--
--  단, 본인이 자기 이름·전화·서명을 고치는 것까지 막으면 안 된다.
--  그래서 '누구 행을 건드리나(using)' 와 '역할을 바꾸나(with check)' 를 따로 본다.
--   · using     : 보호 대상 행은 총관리자만. 다만 본인 행은 본인도.
--   · with check: 역할을 '바꾸지 않았으면' 통과. 바꾸려면 총관리자여야 한다.
--  이러면 본인 프로필 수정은 되고, 스스로 승격하는 건 막힌다.
create or replace function public.member_role_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select community_role from public.members where id = target;
$$;
grant execute on function public.member_role_of(uuid) to authenticated;

drop policy if exists members_protect_superadmin_upd on public.members;
create policy members_protect_superadmin_upd on public.members
  as restrictive for update to authenticated
  using  ( community_role not in ('super_admin','vice_admin')
           or public.is_super_admin()
           or id = auth.uid() )
  with check (
    public.is_super_admin()
    -- 보호 대상(총관리자·부총관리자)으로 '올리는' 것도,
    -- 보호 대상이던 사람을 '내리는' 것도 총관리자만.
    -- 그 외의 역할 변경(학생↔교사 등)은 관리자가 그대로 할 수 있어야 한다.
    or ( community_role not in ('super_admin','vice_admin')
         and coalesce(public.member_role_of(id),'member') not in ('super_admin','vice_admin') )
    -- 본인이 자기 행을 고치되 역할은 그대로 두는 경우 (이름·전화·서명 등)
    or ( id = auth.uid()
         and community_role is not distinct from public.member_role_of(id) )
  );

drop policy if exists members_protect_superadmin_del on public.members;
create policy members_protect_superadmin_del on public.members
  as restrictive for delete to authenticated
  using ( community_role not in ('super_admin','vice_admin') or public.is_super_admin() );

notify pgrst, 'reload schema';


-- ── 6. 확인 ──
select polname as "정책",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end as "대상",
       case when polpermissive then '허용' else '제한' end as "종류"
  from pg_policy where polrelid = 'public.members'::regclass order by 2,1;

-- =====================================================================
--  임명하는 법
--    관리 → 멤버 → 역할 드롭다운에서 '부총관리자' 선택.
--    (총관리자만 지정할 수 있습니다)
--
--  되돌리려면 그 사람 역할을 '관리자'나 '교사'로 바꾸면 됩니다.
--
--  ── 이 SQL 말고 같이 해줘야 하는 것 ──
--  Edge Function 3개를 다시 배포해야 부총관리자가 제대로 돕니다.
--  (안 해도 앱은 멀쩡히 돌아갑니다. 아래 세 가지만 안 될 뿐입니다)
--    · admin-create-student … 내 공동체에서 학생 일괄 등록
--    · drive-list          … 다른 공동체를 볼 때 그 공동체 자료실
--    · store               … 다른 공동체의 매점 현황 보기
--
--  ── 되돌리려면 ──
--  부총관리자를 아예 없애고 싶으면 db/멤버_개인정보_보호_RLS.sql 을
--  다시 한 번 실행하면 이 파일이 바꾼 정책이 전부 원래대로 돌아갑니다.
-- =====================================================================
