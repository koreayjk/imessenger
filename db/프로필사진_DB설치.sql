-- ════════════════════════════════════════════════════════════════════
--  🖼 프로필 사진 (프사)
--
--  지금 채팅·목록에 보이는 아이콘은 '이모지 또는 글자 + 배경색' 입니다.
--  여기에 '내 사진' 을 올릴 수 있게 칸을 하나 만듭니다.
--
--  ⚠️ 생활기록부의 증명사진과는 다른 것입니다.
--     · 증명사진 — 서류에 찍히는 사진. 3:4 세로. 기록부에만 쓰입니다.
--     · 프사     — 채팅·목록에 동그랗게 보이는 사진. 정사각형.
--     둘은 서로 건드리지 않습니다.
--
--  ⚠️ 가장 중요한 것 — 남의 프사를 못 바꾸게 막습니다.
--     지금 members 고치기 규칙은 '같은 공동체면 남의 줄도 고칠 수 있음'
--     입니다 (교사가 학생 학비·담임을 저장해야 해서 그렇습니다).
--     그 틈으로 학생이 친구의 프사를 바꿔 놓을 수 있었습니다.
--     이름을 막아 둔 것(members_name_guard)과 같은 방식으로 막습니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

alter table public.members add column if not exists photo_url text;

comment on column public.members.photo_url is
  '프로필 사진(프사) 주소. 비어 있으면 이모지·글자 아바타를 쓴다. 생활기록부 증명사진과는 다른 것.';

-- 지금 저장된 프사가 무엇인지 규칙 안에서 물어보기 위한 함수.
-- security definer 인 까닭: 규칙을 검사하는 중에 같은 표를 다시 읽으면
-- 규칙이 또 걸려서 제 꼬리를 문다.
create or replace function public.member_photo_of(m uuid)
returns text language sql stable security definer parallel safe
set search_path = public
as $$ select photo_url from public.members where id = m $$;

-- 새로 만든 함수는 기본으로 '아무나' 부를 수 있게 열린다. 먼저 닫는다.
revoke all on function public.member_photo_of(uuid) from public, anon;
grant execute on function public.member_photo_of(uuid) to authenticated;

-- restrictive = 다른 규칙과 'AND' 로 묶인다. 하나라도 어기면 막힌다.
drop policy if exists members_photo_guard on public.members;
create policy members_photo_guard on public.members
  as restrictive for update to authenticated
  using ( true )
  with check (
    photo_url is not distinct from public.member_photo_of(id)  -- 프사를 안 건드렸거나
    or id = auth.uid()                                         -- 내 프사이거나
    or public.can_admin_members()                              -- 관리자이거나
  );

notify pgrst, 'reload schema';

select '설치 끝 — 이제 프로필 사진을 올릴 수 있어요' as "결과";
