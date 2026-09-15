-- ═══════════════════════════════════════════════════════════════
--  홈 위젯 — 공동체마다 홈 화면을 다르게 꾸민다
--  Supabase → SQL Editor 에 통째로 붙여넣고 [Run] 한 번이면 끝납니다.
--  여러 번 실행해도 안전합니다.
-- ═══════════════════════════════════════════════════════════════

-- 공동체별 홈 배치.
--   [{ "k": "위젯키", "w": 1|2, "cfg": { ... } }, ...]
--   w = 1 은 반 칸, 2 는 한 줄 전체.
--   NULL 이면 앱이 기본 배치(맥체인·D-DAY·가정통신문·주간일정표)를 씁니다.
alter table public.communities
  add column if not exists home_widgets jsonb;

comment on column public.communities.home_widgets is
  '홈 화면 위젯 배치. [{k,w,cfg}] 형태의 배열. NULL = 기본 배치';

-- 들어오는 값이 배열인지만 확인한다 (위젯 키는 앱이 걸러낸다).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.communities'::regclass
      and conname  = 'communities_home_widgets_is_array'
  ) then
    alter table public.communities
      add constraint communities_home_widgets_is_array
      check (home_widgets is null or jsonb_typeof(home_widgets) = 'array');
  end if;
end $$;

-- ── 확인 ──
-- 아래가 1줄 나오면 설치 완료입니다.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'communities' and column_name = 'home_widgets';
