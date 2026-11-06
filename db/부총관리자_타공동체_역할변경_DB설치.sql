-- =====================================================================
--  👤 부총관리자 — 다른 공동체 멤버의 **역할만** 바꿀 수 있게
--
--  요청: "부총관리자가 다른 공동체 멤버 교사에서 관리자로 올리는거 가능하게"
--
--  ⚠️ 이것은 db/부총관리자_권한_DB설치.sql 의 "다른 공동체는 눈으로만" 을
--     한 군데 여는 것입니다. 여는 폭을 **역할 하나**로 좁혔습니다.
--
--  남의 공동체에서 열리는 것
--    · community_role 바꾸기 (교사 → 관리자 등)
--
--  남의 공동체에서 **여전히 막히는 것**
--    · 이름 · 사진 · 가입상태(승인/탈퇴) 고치기
--    · 소속 공동체 옮기기 — 남을 내 공동체로 끌어오는 것도 막습니다
--    · 멤버 넣기 · 지우기
--    · 총·부총관리자 자리를 만들거나 건드리기
--    · members 말고 다른 표 전부 (_vice_comm_* 울타리 그대로)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ① '어느 행을 건드릴 수 있나' 에 부총관리자를 넣는다
drop policy if exists members_update_guard on public.members;
create policy members_update_guard on public.members
  as restrictive for update to authenticated
  using (
    auth.uid() is not null
    and ( id = auth.uid()
          or public.is_super_admin()
          or (select public.is_vice_admin())
          or community_id = public.my_community_id() )
  )
  with check (
    auth.uid() is not null
    and ( public.can_admin_members()
          or ( community_role is not distinct from public.member_role_of(id)
               and status is not distinct from public.member_status_of(id) ) )
  );

-- ② members 의 '고치기' 는 공동체 울타리에서 뺀다 (③ 이 대신 지킨다).
--    넣기·지우기 울타리(_vice_comm_ins / _vice_comm_del)는 그대로 둔다.
drop policy if exists members_vice_comm_upd on public.members;

-- ③ 남의 공동체에서는 **역할 말고는 하나도** 못 바꾼다
--
--  ⚠️ 여기서 한 번 틀렸습니다. '내 공동체 사람인가' 를 **바꾼 뒤 값**으로
--     봤더니, 남을 **내 공동체로 끌어오는 것**이 그 조항에 걸려 통과했습니다
--     (그러고 나면 내 사람이라 지울 수도 있습니다).
--     그래서 바뀌기 전 소속(member_community_of)을 봅니다.
drop policy if exists members_vice_other_comm_role_only on public.members;
create policy members_vice_other_comm_role_only on public.members
  as restrictive for update to authenticated
  using (true)
  with check (
    (not (select public.is_vice_admin()))
    or id = (select auth.uid())
    or public.member_community_of(id) = (select public.my_community_id())
    or (
          name         is not distinct from public.member_name_of(id)
      and status       is not distinct from public.member_status_of(id)
      and photo_url    is not distinct from public.member_photo_of(id)
      and community_id is not distinct from public.member_community_of(id)
    )
  );
