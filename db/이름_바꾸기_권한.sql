-- ════════════════════════════════════════════════════════════════════
--  ✏️ 이름은 본인과 관리자만 바꾼다
--
--  "관리자는 관리에서 멤버 가면 자신 소속 사람들의 이름을 변경할 수
--   있게 해줘"
--
--  화면에 단추를 다는 건 쉽습니다. 그런데 서버 쪽을 보니 이미
--  '같은 공동체면 누구나' 남의 이름을 바꿀 수 있었습니다.
--  members_update 정책이 교사가 학생 기록을 저장할 수 있도록
--  '역할·상태만 안 건드리면 통과' 로 열려 있었기 때문입니다.
--  이름은 거기 끼어 있었습니다.
--
--  이름만 따로 잠급니다. 본인이거나 관리자여야 바꿀 수 있습니다.
--  restrictive 라서 기존 정책과 'and' 로 묶입니다 — 교사가 학생
--  기록(생일·보호자 등)을 저장하는 길은 그대로 열려 있습니다.
--
--  ⚠️ 생활기록부 인적사항의 이름은 여기와 다른 칸입니다.
--     거기는 서류에 나가는 정식 이름이고, 여기는 채팅·목록에
--     보이는 이름입니다. 서로 따라가지 않습니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.member_name_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select name from public.members where id = target;
$$;
-- 기본값은 '누구나 실행' 이다. 먼저 걷고 로그인한 사람에게만 준다.
--  안 걷으면 익명으로도 부를 수 있고, 이 함수는 security definer 라
--  RLS 를 넘어 이름을 돌려준다. 멤버 id 를 아는 사람이 이름을 알아낼 수 있다.
revoke all on function public.member_name_of(uuid) from public, anon;
grant execute on function public.member_name_of(uuid) to authenticated;

drop policy if exists members_name_guard on public.members;
create policy members_name_guard on public.members
  as restrictive for update to authenticated
  using ( true )
  with check (
    name is not distinct from public.member_name_of(id)   -- 이름을 안 건드렸거나
    or id = auth.uid()                                    -- 내 이름이거나
    or public.can_admin_members()                         -- 관리자이거나
  );

notify pgrst, 'reload schema';

select '설치 끝 — 이제 이름은 본인과 관리자만 바꿀 수 있어요' as "결과";
