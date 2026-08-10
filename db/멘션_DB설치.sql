-- =====================================================================
--  채팅 @멘션 — 메시지에 언급된 멤버 id 저장 (알림/하이라이트용)
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
alter table public.messages add column if not exists mentions uuid[];
NOTIFY pgrst, 'reload schema';
