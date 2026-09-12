-- =====================================================================
--  자료실 : 공동체마다 다른 구글 드라이브 폴더를 쓰게
--   지금은 폴더 ID 가 Supabase 시크릿(DRIVE_ROOT_FOLDER_ID) 하나에 들어 있어서,
--   시크릿은 프로젝트 단위이므로 모든 공동체가 같은 폴더를 보고 있었습니다.
--   폴더 ID 를 공동체 표로 옮겨 공동체별로 따로 지정합니다.
--
--   · 비워두면 예전처럼 시크릿의 폴더를 씁니다 (설치 직후 그대로 동작)
--   · 값을 넣은 공동체는 그 폴더만 보게 됩니다
--   · 어느 공동체 폴더를 열지는 서버가 호출자의 토큰으로 판단합니다
--     (클라이언트가 보낸 공동체 ID 는 총관리자일 때만 인정)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

alter table public.communities
  add column if not exists drive_root_folder_id text;

comment on column public.communities.drive_root_folder_id is
  '자료실 최상위 구글 드라이브 폴더 ID (폴더 URL 의 마지막 부분). 비우면 시크릿의 기본 폴더 사용';

NOTIFY pgrst, 'reload schema';
