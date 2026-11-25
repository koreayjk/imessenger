-- ═══════════════════════════════════════════════════════════════════
--  📌 채팅방 — 나만 보는 고정
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  개선창 · 김시원 (그레이스 미니스트리, 11/21):
--    「개인적으로 중요한 채팅방은 위쪽에 고정을 할 수 있도록 했으면
--      좋겠습니다」
--
--  지금 있는 고정은 channels.pinned 입니다. 그건 **공동체 전체가 같이
--  보는 고정** 이라, 한 사람이 올리면 모두의 목록이 바뀝니다. 그래서
--  관리자만 만질 수 있습니다. 「개인적으로」 는 그것과 다른 일입니다.
--
--  마침 순서·그룹을 사람마다 따로 적어 두는 덧층(my_channel_prefs)이
--  이미 있습니다. 표를 새로 만들지 않고 거기 칸 하나만 붙입니다.
--  그 표의 규칙은 이미 member_id = auth.uid() — 본인 줄만 보고 씁니다.
--  남의 고정을 들여다보거나 바꿀 길이 처음부터 없습니다.
--
--  넣고 나면 —
--   · 방 옆 📌 를 누르면 나한테만 맨 위로 올라갑니다
--   · 공동체 고정(전체공지 등)은 그대로 위에 있습니다
--   · 다른 사람 목록은 하나도 안 바뀝니다
-- ═══════════════════════════════════════════════════════════════════

alter table public.my_channel_prefs
  add column if not exists pinned boolean not null default false;

--  제대로 붙었는지 확인
do $$
declare n int;
begin
  select count(*) into n from information_schema.columns
   where table_schema='public' and table_name='my_channel_prefs' and column_name='pinned';
  if n <> 1 then raise exception '칸이 안 붙었습니다'; end if;
  raise notice '채팅방 내가 고정 — 설치 완료';
end $$;
