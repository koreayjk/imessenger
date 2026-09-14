-- =====================================================================
--  일정 : 구글 캘린더 연동
--
--   전용 서비스 계정 하나로 공유받은 캘린더를 읽고 씁니다.
--   개별 사용자의 구글 로그인은 필요 없습니다.
--
--   · 서비스 계정 키(비밀값)는 Supabase 시크릿에 하나만 둡니다.
--     시크릿은 프로젝트 단위라 공동체별로 나눌 수 없기 때문입니다.
--   · 대신 '어느 캘린더를 쓸지'는 공동체마다 따로 정합니다.
--     (자료실에서 드라이브 폴더를 나눈 것과 같은 방식)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- ── 공동체마다 다른 캘린더 ──
alter table public.communities
  add column if not exists google_calendar_id text;

comment on column public.communities.google_calendar_id is
  '연동할 구글 캘린더 ID. 캘린더 설정 → 캘린더 통합 → 캘린더 ID. 비우면 연동 안 함';

-- ── 일정 ↔ 구글 일정 짝짓기 ──
alter table public.events
  add column if not exists google_event_id text,
  add column if not exists gcal_synced_at  timestamptz,
  -- 'tcs' : TCS 에서 만들어 구글로 보낸 것
  -- 'google' : 구글에서 가져온 것
  add column if not exists gcal_origin     text;

comment on column public.events.google_event_id is
  '짝이 되는 구글 캘린더 일정의 id. 같은 일정이 두 번 생기지 않게 하는 열쇠';

-- 같은 구글 일정이 한 공동체에 두 번 들어오지 않게
create unique index if not exists events_gcal_uniq
  on public.events (community_id, google_event_id)
  where google_event_id is not null;

create index if not exists events_gcal_sync_idx
  on public.events (community_id, gcal_synced_at);

NOTIFY pgrst, 'reload schema';
