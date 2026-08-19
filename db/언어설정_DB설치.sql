-- =====================================================================
--  공동체 언어 설정 (한국어 ko / 영어 en) — 관리자가 선택, 전체 UI 언어 전환
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
alter table public.communities add column if not exists language text default 'ko';
NOTIFY pgrst, 'reload schema';
