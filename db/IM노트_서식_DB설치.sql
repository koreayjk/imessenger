-- =====================================================================
--  IM노트 : 본문 서식(리치텍스트) 지원
--   본문을 HTML 로도 저장할 수 있게 format 컬럼을 추가합니다.
--   format = 'text'  → 예전 방식(순수 글자).  'html' → 서식 있는 본문
--   앱이 저장할 때와 보여줄 때 모두 허용목록 방식으로 걸러내므로
--   에버노트에서 가져온 HTML 이 그대로 실행될 일은 없습니다.
--  ※ db/IM노트_DB설치.sql 을 먼저 실행한 뒤에 이걸 실행하세요. (재실행 안전)
-- =====================================================================

alter table public.notes add column if not exists format text not null default 'text';

NOTIFY pgrst, 'reload schema';
