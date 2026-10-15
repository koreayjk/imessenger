-- =====================================================================
--  📋 제출란을 한 방에 여러 개
--
--  요청 (개선창)
--   "제출란이 하나 등록하면 다른 것이 등록이 안되네요!
--    제출란에 등록 할 수 있는 갯수가 늘어나면 좋겠습니다"
--
--  왜 하나만 됐나
--   제출란 설정이 channels 표의 칸(checkin_label·checkin_days…)으로
--   박혀 있었습니다. 방 하나에 칸이 한 벌뿐이니 둘째를 만들면 첫째를
--   덮어씁니다. 구조상 하나밖에 될 수 없었습니다.
--
--   그래서 설정을 따로 표로 뺍니다. 한 방에 '플래너', 'Daily Report',
--   '독서기록' 을 나란히 둘 수 있게 됩니다.
--
--  ※ db/제출현황_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.checkin_marks') is null then
    raise exception '먼저 db/제출현황_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- ── 1. 제출란 표 ─────────────────────────────────────────────────
create table if not exists public.checkin_items (
  id         uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  label      text not null,
  days       text not null default '0,1,2,3,4,5,6',   -- 0=일 … 6=토
  require    text not null default 'image',
  keyword    text,
  start_date date,
  exempt     text not null default '',                -- 안 내도 되는 사람
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists checkin_items_ch_idx on public.checkin_items (channel_id, sort, created_at);

comment on table public.checkin_items is
  '채팅방마다의 제출란. 한 방에 여러 개 둘 수 있다.';

-- ── 2. 쓰던 설정을 그대로 옮긴다 ─────────────────────────────────
--  이미 켜 둔 방은 손대지 않아도 그대로 보여야 한다.
insert into public.checkin_items (channel_id, label, days, require, keyword, start_date, exempt, sort)
select c.id,
       coalesce(nullif(c.checkin_label,''), '플래너'),
       coalesce(nullif(c.checkin_days,''), '0,1,2,3,4,5,6'),
       coalesce(nullif(c.checkin_require,''), 'image'),
       c.checkin_keyword,
       c.checkin_start,
       coalesce(c.checkin_exempt, ''),
       0
  from public.channels c
 where c.checkin_on = true
   and not exists (select 1 from public.checkin_items i where i.channel_id = c.id);

-- ── 3. 표시는 제출란마다 ─────────────────────────────────────────
alter table public.checkin_marks add column if not exists item_id uuid
  references public.checkin_items(id) on delete cascade;

--  쓰던 표시를 옮겨 온 제출란에 붙인다
update public.checkin_marks m
   set item_id = i.id
  from public.checkin_items i
 where m.item_id is null
   and i.channel_id = m.channel_id
   and i.sort = 0;

--  같은 날 같은 사람은 제출란마다 하나씩.
--  '부분 색인(where item_id is not null)' 으로 두면 안 된다 — supabase 의
--  upsert 가 ON CONFLICT 로 그 색인을 찾아내지 못한다. 그냥 두면 되는데,
--  Postgres 는 NULL 끼리는 충돌로 보지 않으므로 옛 줄(item_id 없음)은
--  서로 부딪히지 않는다.
alter table public.checkin_marks drop constraint if exists checkin_marks_channel_id_member_id_day_key;
drop index if exists public.checkin_marks_item_uniq;
create unique index if not exists checkin_marks_item_uniq
  on public.checkin_marks (item_id, member_id, day);
create index if not exists checkin_marks_item_day on public.checkin_marks (item_id, day);

-- ── 4. 누가 보고 누가 고치나 ─────────────────────────────────────
--  checkin_marks 와 같은 기준이다. 보기는 그 방 사람, 고치기는 간사 이상.
alter table public.checkin_items enable row level security;

drop policy if exists checkin_items_select on public.checkin_items;
create policy checkin_items_select on public.checkin_items
  for select to authenticated
  using ( public.in_channel(channel_id) or public.can_view_all_communities() );

drop policy if exists checkin_items_write on public.checkin_items;
create policy checkin_items_write on public.checkin_items
  for all to authenticated
  using      ( public.is_staff_member()
               and (public.in_channel(channel_id) or public.can_view_all_communities()) )
  with check ( public.is_staff_member()
               and (public.in_channel(channel_id) or public.can_view_all_communities()) );

grant select, insert, update, delete on public.checkin_items to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select c.name as "채팅방", i.label as "제출란", i.require as "인정 기준", i.days as "세는 요일"
  from public.checkin_items i join public.channels c on c.id = i.channel_id
 order by c.name, i.sort, i.created_at;

-- =====================================================================
--  제출 현황 창에 제출란 이름표가 줄지어 뜨고, [＋] 로 더할 수 있습니다.
--  channels 의 checkin_* 칸은 그대로 둡니다 — 되돌릴 일이 생겼을 때
--  쓰던 설정이 남아 있어야 하기 때문입니다.
-- =====================================================================
