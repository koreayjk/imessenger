-- =====================================================================
--  🔐 members 잠그기 — 로그인 안 한 사람이 읽지도 쓰지도 못하게
--
--  ⚠️ 2차 수정본입니다. 앞 판은 제한(restrictive) 정책만 만들고
--     RLS 를 켜지 않아서 아무 효과가 없었습니다.
--     정책 목록에 허용(permissive) 정책이 하나도 없는데 익명이 읽고 쓰였다는 건
--     members 의 RLS 가 아예 꺼져 있다는 뜻입니다. 이 파일이 그걸 바로잡습니다.
--
--  무엇을 확인했나 (프로덕션에서 직접 재현)
--   1) 읽기 : 로그인 없이 공개 anon 키만으로 members 130명이 전부 읽힘
--             (content-range: 0-129/130) — 이름·이메일·전화·생년월일·주소·
--             보호자연락처·학비까지 함께.
--   2) 쓰기 : 로그인 없이 PATCH 가 통과. 즉 아무나 남의 역할을 관리자로 바꾸거나
--             누구든 탈퇴시킬 수 있는 상태.
--   3) 정책 : 허용 정책 0개, 제한 정책 2개(총관리자 보호)뿐 → RLS 가 꺼져 있음.
--   anon 키는 index.html 안에 있고 저장소가 공개라 누구나 가져다 씁니다.
--
--  ❗ RLS 를 켜는 순간, 허용 정책이 없으면 전부 막힙니다.
--     그래서 이 파일은 '허용 정책을 먼저 만들고 → 마지막에 RLS 를 켭니다'.
--     순서가 중요하니 통째로 한 번에 실행해 주세요.
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

grant execute on function public.is_super_admin()       to authenticated;
grant execute on function public.can_admin_members()    to authenticated;
grant execute on function public.my_community_id()      to authenticated;
grant execute on function public.member_role_of(uuid)   to authenticated;
grant execute on function public.member_status_of(uuid) to authenticated;


-- ── 2. 허용 정책 (이게 있어야 RLS 를 켜도 앱이 돈다) ──
--  전부 'to authenticated' 입니다. 익명(anon)은 어디에도 들어 있지 않으니
--  로그인하지 않으면 한 줄도 읽지 못하고 한 줄도 쓰지 못합니다.

-- 읽기: 내 행 + 내 공동체 사람들. 총관리자는 전부(공동체 전환 때문).
drop policy if exists members_select on public.members;
create policy members_select on public.members
  for select to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or community_id = public.my_community_id()
  );

-- 넣기: 가입할 때 자기 행 하나만. 스스로 승인하거나 관리자가 될 수 없다.
--       (관리자가 학생을 대신 만드는 admin-create-student 는 service_role 이라 영향 없음)
drop policy if exists members_insert on public.members;
create policy members_insert on public.members
  for insert to authenticated
  with check (
    public.can_admin_members()
    or ( id = auth.uid()
         and coalesce(status,'pending') = 'pending'
         and coalesce(community_role,'student')
             not in ('super_admin','community_admin') )
  );

-- 고치기
--  USING = 누구 행을 건드릴 수 있나 → 내 행이거나 같은 공동체(총관리자는 전부)
--  CHECK = 무엇으로 바꿀 수 있나
--          관리자면 자유. 관리자가 아니면 역할·상태를 '바꾸지 않은' 경우만 통과.
--          그래야 교사가 학생 학비·담임을 저장하는 건 되면서,
--          본인이 스스로 관리자가 되거나 스스로 승인하는 건 막힌다.
drop policy if exists members_update on public.members;
create policy members_update on public.members
  for update to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or community_id = public.my_community_id()
  )
  with check (
    public.can_admin_members()
    or ( community_role is not distinct from public.member_role_of(id)
         and status     is not distinct from public.member_status_of(id) )
  );

-- 지우기: 앱은 members 를 직접 지우지 않는다(탈퇴는 status 만 바꾼다). 관리자만 남겨 둔다.
drop policy if exists members_delete on public.members;
create policy members_delete on public.members
  for delete to authenticated
  using ( public.can_admin_members() );


-- ── 3. 총관리자 보호 (이미 있으면 그대로 다시 깔아 둔다) ──
drop policy if exists members_protect_superadmin_upd on public.members;
create policy members_protect_superadmin_upd on public.members
  as restrictive for update to authenticated
  using  ( community_role is distinct from 'super_admin' or public.is_super_admin() )
  with check ( community_role is distinct from 'super_admin' or public.is_super_admin() );

drop policy if exists members_protect_superadmin_del on public.members;
create policy members_protect_superadmin_del on public.members
  as restrictive for delete to authenticated
  using ( community_role is distinct from 'super_admin' or public.is_super_admin() );


-- ── 4. 이제 RLS 를 켠다 (허용 정책을 다 만든 뒤에) ──
alter table public.members enable row level security;

notify pgrst, 'reload schema';


-- ── 5. 확인 ──
select relrowsecurity as "RLS 켜짐(t여야 함)" from pg_class
 where oid = 'public.members'::regclass;

select polname as "정책",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end as "대상",
       case when polpermissive then '허용' else '제한' end as "종류"
  from pg_policy where polrelid = 'public.members'::regclass order by 2,1;


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
--  ❗ 하나라도 안 되면 이 한 줄로 즉시 원래 상태(RLS 꺼짐)로 되돌립니다:
--
--       alter table public.members disable row level security;
--
--     되돌린 뒤 어디가 막혔는지 알려주시면 조건을 고쳐 드리겠습니다.
--     (정책은 남겨 둬도 RLS 가 꺼져 있으면 아무 영향이 없습니다)
-- =====================================================================
