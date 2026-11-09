-- ══════════════════════════════════════════════════════════════
--  일정 — 반복 (구글 캘린더 반복 일정 연동)
--  (개선창 ⑭ · 박윤환 · RM · 2026-11-06)
-- ══════════════════════════════════════════════════════════════
--
--  바라던 것 : "일정에서, 구글 캘린더에 반복으로 설정한 내용이 TCS와
--   연동되지 않고, 최초로 기록한 일정만 서로 동기화 되는 부분을 개선
--   부탁드립니다."
--
--  맞는 말씀입니다. 지금 gcal-sync 는 일부러 `singleEvents: false` 로
--  두고 **대표 일정 한 건만** 들여오면서 설명에 '🔁 매주 …' 만 적어
--  두었습니다. events 표에 '반복' 이라는 개념이 아예 없었기 때문입니다.
--
--  고치는 방향 — 줄을 늘리지 않고 규칙을 들고 온다
--   · 반복 규칙(RRULE) 을 한 칸에 담고, 달력이 그릴 때 펼칩니다.
--     펼쳐서 줄로 집어넣으면 매주 반복 하나가 2년 반 치 130줄이 되고,
--     고칠 때마다 130줄을 따라다녀야 합니다.
--   · 구글에서 '이 회차만 지운' 날은 rrule_except 에 담아 빼고 그립니다.
--   · 구글에서 '이 회차만 바꾼' 일정은 그 날짜를 예외로 빼고, 바뀐 내용을
--     따로 한 줄로 넣습니다 (그 날은 바뀐 것만 보입니다).
-- ══════════════════════════════════════════════════════════════

--  RRULE 본문. 'RRULE:' 머리는 떼고 담습니다 — 예: FREQ=WEEKLY;BYDAY=WE
alter table public.events add column if not exists rrule text;

--  그 회차만 빠지는 날들 (구글에서 지운 회차 · 따로 바뀐 회차의 원래 날짜)
alter table public.events add column if not exists rrule_except date[] not null default '{}';

--  반복 일정의 '이 회차만 바뀐 것' 은 대표 일정을 가리켜 둡니다.
--  (대표를 지우면 같이 지워집니다 — 혼자 떠도는 회차가 남지 않게)
alter table public.events add column if not exists rrule_parent uuid
  references public.events(id) on delete cascade;

create index if not exists events_rrule_parent_idx on public.events (rrule_parent);

--  반복이 있는 일정만 따로 찾을 일이 많습니다 (펼칠 거리를 고를 때)
create index if not exists events_rrule_idx on public.events (community_id) where rrule is not null;

comment on column public.events.rrule        is 'iCalendar RRULE 본문 (머리 RRULE: 는 뗀 것). 비면 반복 아님';
comment on column public.events.rrule_except is '그 회차만 빠지는 날들 (YYYY-MM-DD)';
comment on column public.events.rrule_parent is '반복 일정의 회차별 수정본이 가리키는 대표 일정';
