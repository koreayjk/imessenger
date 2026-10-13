-- =====================================================================
--  🔧 부총관리자가 본인 공동체 멤버를 관리하지 못하던 것 되돌리기
--
--  증상
--    부총관리자가 「멤버 → 탈퇴」를 눌러도 되지 않습니다.
--    가입 승인도, 역할 변경도 막혀 있습니다. 관리자(community_admin)
--    와 총관리자는 됩니다.
--
--  원인
--    db/부총관리자_DB설치.sql 은 members_update 에
--        or (public.is_vice_admin() and community_id = public.my_community_id())
--    를 넣어, 부총관리자가 '자기 공동체 안에서만' 관리자 노릇을 하게
--    했습니다.
--    그런데 뒤에 깐 db/학부모_1_칸막이_DB설치.sql 이 members_update 를
--    통째로 갈아끼우면서 그 조항을 빠뜨렸습니다. 허용 정책은 이름이
--    같으면 덮어쓰이므로, 조용히 권한이 사라졌습니다.
--    db/학부모_2_가입연결_DB설치.sql 의 제한 정책도 같은 이유로
--    부총관리자의 역할 변경을 막고 있습니다.
--
--  이 파일이 하는 일
--    두 정책에 부총관리자 조항을 다시 넣습니다. '자기 공동체 안에서만'
--    이라는 조건은 그대로입니다 — 남의 공동체는 여전히 못 건드립니다.
--    총관리자·부총관리자 자리를 건드리는 것도 여전히 총관리자만 됩니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regprocedure('public.is_vice_admin()') is null then
    raise exception '먼저 db/부총관리자_DB설치.sql 을 실행해주세요.';
  end if;
  if to_regprocedure('public.staff_of(uuid)') is null then
    raise exception '먼저 db/학부모_1_칸막이_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- ── 1. 고치기 — 부총관리자 조항을 되살린다 ───────────────────────
--  using  : 누구 행을 건드릴 수 있나
--  check  : 바꾼 뒤의 행이 괜찮은가 (역할·상태를 바꾸려면 자격이 필요)
drop policy if exists members_update on public.members;
create policy members_update on public.members
  for update to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or public.staff_of(community_id)
  )
  with check (
    public.can_admin_members()
    -- ↓ 이 줄이 빠져 있었습니다
    or ( public.is_vice_admin() and community_id = public.my_community_id() )
    or ( community_role is not distinct from public.member_role_of(id)
         and status     is not distinct from public.member_status_of(id) )
  );

-- ── 2. 학부모 잠금 정책에도 같은 조항 ────────────────────────────
--  이 정책의 목적은 '학부모로 들어온 사람이 스스로 교사가 되는 것'을
--  막는 것입니다. 부총관리자는 그 대상이 아닙니다.
drop policy if exists members_parent_stays_parent on public.members;
create policy members_parent_stays_parent on public.members
  as restrictive for update to authenticated
  using ( true )
  with check (
    public.can_admin_members()
    or ( public.is_vice_admin() and community_id = public.my_community_id() )
    or community_role is not distinct from public.member_role_of(id)
  );

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select polname as "정책",
       case when polpermissive then '허용' else '제한' end as "종류"
  from pg_policy where polrelid = 'public.members'::regclass
   and polcmd in ('w','*') order by 1;

-- =====================================================================
--  이걸 실행하면 부총관리자가 본인 공동체에서
--    · 가입 승인 / 거절
--    · 멤버 탈퇴
--    · 역할 변경 (총관리자·부총관리자 자리는 제외)
--  를 할 수 있게 됩니다. 남의 공동체는 그대로 열람만 됩니다.
-- =====================================================================
