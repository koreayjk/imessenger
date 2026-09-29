-- =====================================================================
--  🔐 members 잠그기 — 로그인 안 한 사람이 읽지도 쓰지도 못하게
--
--  무엇을 확인했나 (프로덕션에서 직접 재현)
--   1) 읽기 : 로그인 없이 공개 anon 키만으로 members 전원이 읽힙니다.
--             content-range: 0-129/130 — 130명 전부.
--             이름·이메일·전화·생년월일·주소·보호자연락처·학비까지 같이 나옵니다.
--   2) 쓰기 : 로그인 없이 PATCH 가 통과합니다.
--             즉 지금은 아무나 남의 역할을 관리자로 바꾸거나,
--             누구든 탈퇴(status='removed') 시킬 수 있습니다.
--   anon 키는 index.html 안에 있고 저장소가 공개라 누구나 가져다 씁니다.
--
--  왜 이렇게 고치나
--   기존 정책을 지우지 않고 restrictive(제한) 정책을 덧댑니다.
--   restrictive 는 기존 정책과 AND 로 묶여서 권한을 넓히는 일이 절대 없고,
--   문제가 생기면 그 정책만 지우면 즉시 원상복구됩니다. (맨 아래 되돌리기)
--
--  앱이 깨지지 않는 근거 (코드를 전부 따라가 확인했습니다)
--   · 로그인 화면의 '대기/거절/탈퇴' 안내는 signInWithPassword 가 끝난 뒤
--     (= 이미 로그인된 상태) 본인 행을 읽어 띄웁니다. 익명 읽기가 필요 없습니다.
--   · 가입 화면의 공동체 목록은 members 가 아니라 communities 를 읽습니다.
--   · 공개 가정통신문(#nl=) 은 newsletters 만 읽습니다.
--   · 이메일 확인이 꺼져 있어(mailer_autoconfirm=true) 가입 직후 바로 로그인
--     상태가 됩니다. 그래서 가입 INSERT 도 'auth.uid() = 본인' 으로 통과합니다.
--   · Edge Function 은 service_role 이라 RLS 자체를 통과합니다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================


-- ── 0. 지금 걸린 정책 보기 (아무것도 안 바꿉니다) ──
select polname                                   as "정책 이름",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE'
                   else 'ALL' end                as "대상",
       case when polpermissive then '허용' else '제한' end as "종류",
       coalesce((select string_agg(r.rolname, ', ')
                   from pg_roles r where r.oid = any(polroles)), 'public(전체)') as "적용 역할"
  from pg_policy where polrelid = 'public.members'::regclass
 order by polcmd, polname;


-- ── 1. 헬퍼 ──
--  members 정책 안에서 members 를 그냥 조회하면 무한 재귀가 납니다.
--  security definer 로 빼서 RLS 를 타지 않게 합니다.
--  stable 이라 UPDATE 도중에 불러도 '바뀌기 전' 값을 돌려줍니다 —
--  역할을 몰래 바꾸는지 가려내는 데 이 성질을 씁니다.

create or replace function public.is_super_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid() and community_role = 'super_admin');
$$;

create or replace function public.can_admin_members()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','community_admin'));
$$;

create or replace function public.my_community_id()
returns uuid language sql security definer stable set search_path = public as $$
  select community_id from public.members where id = auth.uid();
$$;

create or replace function public.member_role_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select community_role from public.members where id = target;
$$;

create or replace function public.member_status_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select status from public.members where id = target;
$$;

-- anon 에게도 실행 권한을 준다. 안 주면 정책을 훑는 순간 '권한 없음' 오류가 터져
-- 깔끔히 0건이 아니라 화면에 '불러오기 실패'가 뜬다.
-- 로그인 안 한 사람이 부르면 auth.uid() 가 null 이라 아무것도 안 나온다.
grant execute on function public.is_super_admin()        to anon, authenticated;
grant execute on function public.can_admin_members()     to anon, authenticated;
grant execute on function public.my_community_id()       to anon, authenticated;
grant execute on function public.member_role_of(uuid)    to anon, authenticated;
grant execute on function public.member_status_of(uuid)  to anon, authenticated;


-- ── 2. 읽기 ──
--  로그인 안 했으면 한 줄도 못 읽는다.
--  로그인했으면 내 행 + 내 공동체 사람들. 총관리자는 전부(공동체 전환 때문).
drop policy if exists members_read_guard on public.members;
create policy members_read_guard on public.members
  as restrictive for select
  using (
    auth.uid() is not null
    and ( id = auth.uid()
          or public.is_super_admin()
          or community_id = public.my_community_id() )
  );


-- ── 3. 넣기 ──
--  가입할 때 자기 행 하나만. 스스로 승인하거나 관리자가 될 수 없다.
--  (관리자가 학생을 대신 만드는 admin-create-student 는 service_role 이라 영향 없음)
drop policy if exists members_insert_guard on public.members;
create policy members_insert_guard on public.members
  as restrictive for insert
  with check (
    auth.uid() is not null
    and ( id = auth.uid() or public.can_admin_members() )
    and ( public.can_admin_members()
          or ( coalesce(status,'pending') = 'pending'
               and coalesce(community_role,'student')
                   not in ('super_admin','community_admin') ) )
  );


-- ── 4. 고치기 ──
--  USING  = 누구 행을 건드릴 수 있나 → 내 행이거나 같은 공동체(총관리자는 전부)
--  CHECK  = 무엇으로 바꿀 수 있나
--           관리자면 자유. 관리자가 아니면 역할·상태를 '바꾸지 않은' 경우만 통과.
--           그래야 교사가 학생 학비·담임을 저장하는 건 되면서,
--           본인이 스스로 관리자가 되는 건 막힌다.
drop policy if exists members_update_guard on public.members;
create policy members_update_guard on public.members
  as restrictive for update
  using (
    auth.uid() is not null
    and ( id = auth.uid()
          or public.is_super_admin()
          or community_id = public.my_community_id() )
  )
  with check (
    auth.uid() is not null
    and ( public.can_admin_members()
          or ( community_role is not distinct from public.member_role_of(id)
               and status     is not distinct from public.member_status_of(id) ) )
  );


-- ── 5. 지우기 ──
--  앱은 members 를 직접 지우지 않는다(탈퇴는 status 만 바꾼다). 관리자만 남겨 둔다.
drop policy if exists members_delete_guard on public.members;
create policy members_delete_guard on public.members
  as restrictive for delete
  using ( auth.uid() is not null and public.can_admin_members() );


notify pgrst, 'reload schema';


-- =====================================================================
--  ✅ 실행한 뒤 이것만 눌러봐 주세요 (3분)
--
--   1. 시크릿 창으로 앱 열기 → 로그인 되나
--   2. 채팅 오른쪽 멤버 목록 보이나
--   3. 학사 → 학생 목록 보이나
--   4. 관리 → 멤버 승인 / 역할 변경 / 탈퇴 되나
--   5. 학사 → 재정 → 학비에서 학생 월 학비 저장되나  ← 교사 권한 확인
--   6. 총관리자로 공동체 전환 되나
--   7. 새 계정 가입 되나
--
--  ❗ 하나라도 안 되면 그 줄만 지워서 즉시 되돌립니다:
--       drop policy members_read_guard   on public.members;
--       drop policy members_insert_guard on public.members;
--       drop policy members_update_guard on public.members;
--       drop policy members_delete_guard on public.members;
--
--  어디가 막혔는지 알려주시면 조건을 고쳐 드리겠습니다.
-- =====================================================================
