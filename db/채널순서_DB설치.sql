-- =====================================================================
--  채팅 토픽 순서 — 채널 정렬값(sort) 저장 (드래그로 순서 변경)
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
alter table public.channels add column if not exists sort int;
NOTIFY pgrst, 'reload schema';
