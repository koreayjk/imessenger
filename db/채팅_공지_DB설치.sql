-- =====================================================================
--  채팅방 공지글(고정) 기능 — 메시지를 공지로 등록해 상단 고정
--  channels 테이블에 공지 관련 컬럼 추가. (재실행 안전)
--  권한(간사 이상)은 앱에서 제어하며, 기존 channels UPDATE 정책을 그대로 사용합니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요.
-- =====================================================================

alter table public.channels add column if not exists announce_text    text;
alter table public.channels add column if not exists announce_name    text;
alter table public.channels add column if not exists announce_msg_id  uuid;
alter table public.channels add column if not exists announce_by      uuid;
alter table public.channels add column if not exists announce_at      timestamptz;

NOTIFY pgrst, 'reload schema';
