-- =====================================================================
--  TCS — 아직 설치 안 된 것 한꺼번에
--  순서대로 한 번에 돕니다. 재실행해도 안전합니다.
-- =====================================================================

-- ══════ db/트리플스쿨_예전읽음_DB설치.sql ══════
-- =====================================================================
--  📖 트리플스쿨 — '예전에 읽었어요' 바로 체크
--
--  요청: "이전에 읽었던 트리플 스쿨을 기록하려 하는데 독후감을 작성해야
--   해서 어려움이 있네요! 혹시 바로 체크가 가능하게끔 하는 기능을
--   추가해 주실 수 있으실까요?"
--
--  지금은 독후감 60단어를 채워야만 '읽음' 이 됩니다. 입학 전에 읽은
--  책까지 전부 다시 독후감을 쓰게 하는 건 무리입니다.
--
--  ⚠️ 다만 '독후감을 쓴 읽음' 과 '예전에 읽은 체크' 는 구별해야 합니다.
--     같아 보이면 선생님이 진도를 잘못 읽습니다. prior_read 로 가립니다.
--     생활기록부(PDF)에도 들어가지 않습니다 — 담을 글이 없습니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.reading_logs') is null then
    raise exception '먼저 트리플스쿨(필독서) DB 설치를 해주세요.';
  end if;
end $$;

-- 예전에 읽은 체크인가
alter table public.reading_logs
  add column if not exists prior_read boolean not null default false;

-- 언제 읽었는지 기억 안 날 수 있습니다. 비워둘 수 있게 합니다.
-- (칸 이름이 다른 곳에서도 멈추지 않게 있을 때만 건드립니다)
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='reading_logs'
                and column_name='read_date' and is_nullable='NO') then
    execute 'alter table public.reading_logs alter column read_date drop not null';
  end if;
end $$;

comment on column public.reading_logs.prior_read is
  'true = 독후감 없이 ''예전에 읽었다'' 고만 체크한 것. 생활기록부에는 넣지 않는다.';

create index if not exists reading_logs_prior_idx
  on public.reading_logs (student_id, prior_read);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select
  count(*)                                   as "전체 읽음",
  count(*) filter (where prior_read)          as "예전에 읽음 체크",
  count(*) filter (where not prior_read)      as "독후감 쓴 것"
from public.reading_logs;


-- ══════ db/기도제목_댓글_DB설치.sql ══════
-- =====================================================================
--  💬 기도제목 댓글 — 함께 기도하고, 격려하는 자리
--
--  요청: "댓글을 달아서, 기도하고 있는 부분과 격려할 수 있는 란이
--   있으면 좋겠어요!"
--
--  지금은 '🙏 함께 기도' 숫자만 올라갑니다. 숫자는 몇 명인지는
--  알려주지만 무슨 말을 해주고 싶었는지는 담지 못합니다.
--
--  ⚠️ 기도제목은 사사로운 이야기가 오가는 자리입니다. 댓글도 같은
--     공동체 사람만 보게 막습니다. 지우는 건 쓴 사람과 교직원만
--     할 수 있습니다 — 남의 말을 아무나 지우면 안 되고, 마음을
--     다치게 하는 말이 달렸을 때 치울 사람은 있어야 합니다.
--
--  ※ db/전체잠그기_RLS.sql 과 db/신고차단_DB설치.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.prayers') is null then
    raise exception 'prayers 표가 없습니다.';
  end if;
end $$;

create table if not exists public.prayer_comments (
  id           uuid primary key default gen_random_uuid(),
  prayer_id    uuid not null references public.prayers(id) on delete cascade,
  community_id uuid not null,
  member_id    uuid not null,
  author_name  text,
  content      text not null,
  created_at   timestamptz not null default now()
);

create index if not exists prayer_comments_pid_idx
  on public.prayer_comments (prayer_id, created_at);

comment on table public.prayer_comments is
  '기도제목에 다는 댓글. 같은 공동체 사람만 보고, 쓴 사람과 교직원만 지운다.';

alter table public.prayer_comments enable row level security;

-- 같은 공동체 사람만 읽는다
drop policy if exists prayer_comments_select on public.prayer_comments;
create policy prayer_comments_select on public.prayer_comments
  for select to authenticated using ( public.mine_comm(community_id) );

-- 내 이름으로만 쓴다. 남의 이름으로 댓글을 달 수 있으면 안 된다.
drop policy if exists prayer_comments_insert on public.prayer_comments;
create policy prayer_comments_insert on public.prayer_comments
  for insert to authenticated
  with check ( member_id = auth.uid() and public.mine_comm(community_id) );

-- 고치는 건 쓴 사람만
drop policy if exists prayer_comments_update on public.prayer_comments;
create policy prayer_comments_update on public.prayer_comments
  for update to authenticated
  using ( member_id = auth.uid() ) with check ( member_id = auth.uid() );

-- 지우는 건 쓴 사람과 교직원
drop policy if exists prayer_comments_delete on public.prayer_comments;
create policy prayer_comments_delete on public.prayer_comments
  for delete to authenticated
  using ( member_id = auth.uid() or public.staff_of(community_id) );

grant select, insert, update, delete on public.prayer_comments to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select policyname as "정책", cmd as "대상"
  from pg_policies where schemaname='public' and tablename='prayer_comments'
 order by 2, 1;


-- ══════ db/채팅_공지_누적_DB설치.sql ══════
-- =====================================================================
--  📢 지난 공지 쌓기
--
--  요청: "공지사항이나 매번 사용하는 것들을 상단에 고정되면 올라가지
--   않고도 확인할 수 있으면 편리할 것 같네요. 고정되었던 내용들도
--   누적으로 볼 수 있도록 펼쳐서 볼 수 있게 되면 더 좋을 것 같아요!"
--
--  상단 고정은 이미 있습니다. 다만 방마다 한 줄(channels.announce_*)
--  이라, 새 공지를 올리면 앞의 공지가 그 자리에서 사라집니다.
--  지난 공지를 찾으려면 채팅을 거슬러 올라가야 합니다 —
--  "올라가지 않고도 확인" 하고 싶다는 말씀이 바로 그 뜻입니다.
--
--  지금 걸린 공지는 그대로 channels 에 둡니다(화면이 그대로 돕니다).
--  이 표는 지나간 것까지 쌓아 두는 자리입니다.
--
--  ※ db/채팅_공지_DB설치.sql 과 db/전체잠그기_RLS.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'channels 표가 없습니다.';
  end if;
end $$;

create table if not exists public.channel_notices (
  id           uuid primary key default gen_random_uuid(),
  channel_id   uuid not null references public.channels(id) on delete cascade,
  community_id uuid,
  text         text not null,
  author_name  text,                 -- 원래 글쓴이 (공지로 올린 사람과 다를 수 있다)
  message_id   uuid,                 -- 원문으로 찾아가려고
  created_by   uuid,                 -- 공지로 올린 사람
  created_at   timestamptz not null default now(),
  removed_at   timestamptz,          -- 내려간 때. 비어 있으면 '지금 걸린 공지'
  removed_by   uuid
);

create index if not exists channel_notices_ch_idx
  on public.channel_notices (channel_id, created_at desc);
-- 방마다 '지금 걸린 공지' 는 하나뿐이어야 합니다.
create unique index if not exists channel_notices_live_uq
  on public.channel_notices (channel_id) where removed_at is null;

comment on table public.channel_notices is
  '채팅방 공지 보관함. 지금 걸린 공지는 channels.announce_* 에 있고, 여기엔 지나간 것까지 쌓인다.';

alter table public.channel_notices enable row level security;

-- 볼 수 있는 방의 공지는 볼 수 있다. 어차피 배너로 보던 글이다.
drop policy if exists channel_notices_select on public.channel_notices;
create policy channel_notices_select on public.channel_notices
  for select to authenticated
  using ( channel_id in (select public.my_channel_ids()) );

-- 올리고 내리는 건 그 방을 맡은 교직원만. 화면에서도 막고 있지만,
-- 화면만 믿으면 아무나 남의 방에 공지를 꽂을 수 있다.
drop policy if exists channel_notices_insert on public.channel_notices;
create policy channel_notices_insert on public.channel_notices
  for insert to authenticated
  with check ( public.can_moderate_channel(channel_id) and created_by = auth.uid() );

drop policy if exists channel_notices_update on public.channel_notices;
create policy channel_notices_update on public.channel_notices
  for update to authenticated
  using ( public.can_moderate_channel(channel_id) )
  with check ( public.can_moderate_channel(channel_id) );

drop policy if exists channel_notices_delete on public.channel_notices;
create policy channel_notices_delete on public.channel_notices
  for delete to authenticated
  using ( public.can_moderate_channel(channel_id) );

grant select, insert, update, delete on public.channel_notices to authenticated;

-- 지금 걸려 있는 공지를 보관함에도 한 줄 넣어 둡니다 (한 번만).
insert into public.channel_notices (channel_id, community_id, text, author_name, message_id, created_by, created_at)
select c.id, c.community_id, c.announce_text, c.announce_name, c.announce_msg_id, c.announce_by,
       coalesce(c.announce_at, now())
  from public.channels c
 where coalesce(trim(c.announce_text), '') <> ''
   and not exists (select 1 from public.channel_notices n
                    where n.channel_id = c.id and n.removed_at is null);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select count(*) filter (where removed_at is null) as "지금 걸린 공지",
       count(*) filter (where removed_at is not null) as "지난 공지",
       count(*) as "전체"
  from public.channel_notices;


-- ══════ db/성구암송_DB설치.sql ══════
-- =====================================================================
--  📜 성구암송 — 60구절 · 소교리문답
--
--  요청: "학사란 윗 부분에 트리플스쿨 옆에 성구암송 칸을 넣어주시면
--   좋겠습니다. 성구암송 안에서 60구절이랑 소교리문답 체크를 하고
--   싶은데, 이 부분은 어떻게 할 수 있을지요~"
--   + "암송체크는 교사도 체크하게"
--
--  두 단계입니다 — 학생이 '외웠어요' 체크하고, 교사가 '확인' 도장을
--  찍습니다. 교사가 곧바로 둘 다 찍을 수도 있습니다(학생 앞에서
--  듣고 바로 처리할 때).
--
--  ⚠️ '확인' 은 학생이 스스로 찍으면 안 됩니다. 그러면 확인이 아무
--     뜻이 없습니다. 그런데 RLS 로는 '이 칸만 못 고치게' 를 깔끔하게
--     못 막습니다. 그래서 체크/확인을 함수로만 하게 하고, 표에는
--     읽기만 열어 둡니다. 함수 안에서 누가 부른 건지 다시 봅니다.
--
--  ※ db/전체잠그기_RLS.sql 과 db/신고차단_DB설치.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 1. 외울 거리 ────────────────────────────────────────────────
create table if not exists public.memory_items (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('verse','catechism')),
  no           int  not null,            -- 1..60, 1..107
  title        text not null,            -- '요한복음 3:16' | '제1문'
  body         text,                     -- 구절 본문 | 문(질문)
  answer       text,                     -- 소교리문답의 답
  community_id uuid,                     -- 비어 있으면 전 공동체 공통
  sort         int,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);
-- 한글·영어를 따로 담기 전의 색인. 언어 칸이 생긴 뒤에는
-- db/성구암송_분류언어_DB설치.sql 이 lang 을 넣은 색인으로 바꿔 둔다.
-- 그 뒤에 이 파일을 다시 돌려도 멈추지 않게, 언어 칸이 있으면 건너뛴다.
-- (안 그러면 같은 번호의 한글·영어가 겹쳐 색인을 못 만든다)
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'memory_items'
                    and column_name = 'lang') then
    create unique index if not exists memory_items_uq
      on public.memory_items (kind, no, coalesce(community_id, '00000000-0000-0000-0000-000000000000'::uuid));
  end if;
end $$;
create index if not exists memory_items_kind_idx on public.memory_items (kind, sort, no);

comment on table public.memory_items is
  '암송 항목. community_id 가 비어 있으면 모든 공동체가 같이 쓴다.';

-- ── 2. 누가 무엇을 외웠나 ───────────────────────────────────────
create table if not exists public.memory_checks (
  id           uuid primary key default gen_random_uuid(),
  item_id      uuid not null references public.memory_items(id) on delete cascade,
  student_id   uuid not null,
  community_id uuid,
  checked_at   timestamptz,      -- 학생이 '외웠어요' 한 때
  confirmed_at timestamptz,      -- 교사가 '확인' 한 때
  confirmed_by uuid,
  updated_at   timestamptz not null default now(),
  unique (item_id, student_id)
);
create index if not exists memory_checks_student_idx on public.memory_checks (student_id);
create index if not exists memory_checks_item_idx    on public.memory_checks (item_id);

-- ── 3. 보는 권한 ────────────────────────────────────────────────
alter table public.memory_items  enable row level security;
alter table public.memory_checks enable row level security;

drop policy if exists memory_items_select on public.memory_items;
create policy memory_items_select on public.memory_items
  for select to authenticated
  using ( community_id is null or public.mine_comm(community_id) );

-- 항목을 더하고 고치는 건 교직원만
drop policy if exists memory_items_write on public.memory_items;
create policy memory_items_write on public.memory_items
  for all to authenticated
  using ( public.staff_of(coalesce(community_id, public.my_community_id())) )
  with check ( public.staff_of(coalesce(community_id, public.my_community_id())) );

-- 내 체크는 내가, 학생 전체는 교직원이 본다
drop policy if exists memory_checks_select on public.memory_checks;
create policy memory_checks_select on public.memory_checks
  for select to authenticated
  using ( student_id = auth.uid() or public.staff_of(community_id) );

-- 쓰기는 아래 함수로만. 표에 직접 쓰는 길은 열지 않는다.
grant select on public.memory_items  to authenticated;
grant select on public.memory_checks to authenticated;
grant insert, update, delete on public.memory_items to authenticated;

-- ── 4. 체크 · 확인 (함수로만) ───────────────────────────────────
--  학생이 '외웠어요' 를 켜고 끈다. 확인 도장은 건드리지 못한다.
create or replace function public.memory_check(p_item uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_cid uuid;
begin
  select community_id into v_cid from public.members where id = auth.uid();
  if v_cid is null then raise exception '로그인이 필요합니다'; end if;

  insert into public.memory_checks (item_id, student_id, community_id, checked_at, updated_at)
  values (p_item, auth.uid(), v_cid, case when p_on then now() else null end, now())
  on conflict (item_id, student_id) do update
    set checked_at = case when p_on then coalesce(public.memory_checks.checked_at, now()) else null end,
        -- 학생이 체크를 풀면 교사 확인도 같이 풀린다. 안 그러면
        -- '학생은 안 외웠다는데 확인은 찍혀 있는' 줄이 남는다.
        confirmed_at = case when p_on then public.memory_checks.confirmed_at else null end,
        confirmed_by = case when p_on then public.memory_checks.confirmed_by else null end,
        updated_at = now();
end $$;
grant execute on function public.memory_check(uuid, boolean) to authenticated;

--  교사가 '확인' 도장을 찍고 뗀다. 학생이 아직 체크 안 했으면
--  체크까지 같이 찍는다 — 교사가 직접 듣고 처리하는 경우다.
create or replace function public.memory_confirm(p_item uuid, p_student uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_cid uuid;
begin
  select community_id into v_cid from public.members where id = p_student;
  if v_cid is null then raise exception '학생을 찾을 수 없습니다'; end if;
  if not public.staff_of(v_cid) then raise exception '확인 권한이 없습니다'; end if;

  insert into public.memory_checks (item_id, student_id, community_id, checked_at, confirmed_at, confirmed_by, updated_at)
  values (p_item, p_student, v_cid,
          case when p_on then now() else null end,
          case when p_on then now() else null end,
          case when p_on then auth.uid() else null end,
          now())
  on conflict (item_id, student_id) do update
    set checked_at   = case when p_on then coalesce(public.memory_checks.checked_at, now()) else public.memory_checks.checked_at end,
        confirmed_at = case when p_on then now() else null end,
        confirmed_by = case when p_on then auth.uid() else null end,
        updated_at = now();
end $$;
grant execute on function public.memory_confirm(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "갈래", count(*) as "항목 수" from public.memory_items group by 1 order by 1;

-- =====================================================================
--  다음: 외울 거리를 넣으세요.
--   · db/성구암송_내용_60구절.sql
--   · db/성구암송_내용_소교리문답.sql
--  둘 다 '선생님이 화면에서 고칠 수 있는' 값입니다. 쓰시는 번역과
--  다르면 학사 → 성구암송 → 항목 관리 에서 통째로 바꿀 수 있습니다.
-- =====================================================================


-- ══════ db/성구암송_분류언어_DB설치.sql ══════
-- =====================================================================
--  📜 성구암송 — 분류(A~E · 주제)와 언어(한글 · 영어)
--
--  네비게이토 주제별 성구암송(TMS)은 다섯 묶음 × 주제 여섯 × 두 구절
--  = 60구절입니다. 묶음과 주제를 담을 칸이 필요합니다.
--
--  그리고 한글과 영어를 '따로' 체크합니다. 한글로 외운 것과 영어로
--  외운 것은 다른 일이니까요. 같은 구절이라도 줄을 따로 둡니다.
--
--  ※ db/성구암송_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.memory_items') is null then
    raise exception '먼저 db/성구암송_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

alter table public.memory_items
  add column if not exists lang   text not null default 'ko',
  add column if not exists series text,          -- 'A. 새로운 삶'
  add column if not exists topic  text;          -- '중심되신 그리스도'

alter table public.memory_items drop constraint if exists memory_items_lang_ok;
alter table public.memory_items add constraint memory_items_lang_ok
  check (lang in ('ko','en'));

-- 같은 번호라도 언어가 다르면 다른 줄이다
drop index if exists public.memory_items_uq;
create unique index if not exists memory_items_uq2
  on public.memory_items (kind, lang, no, coalesce(community_id, '00000000-0000-0000-0000-000000000000'::uuid));

create index if not exists memory_items_kind_lang_idx
  on public.memory_items (kind, lang, sort, no);

comment on column public.memory_items.lang is
  'ko = 한글 · en = 영어. 같은 구절이라도 줄을 따로 두어 각각 체크한다.';
comment on column public.memory_items.series is '큰 묶음 (예: A. 새로운 삶)';
comment on column public.memory_items.topic  is '주제 (예: 중심되신 그리스도)';

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "갈래", lang as "말", count(*) as "항목 수"
  from public.memory_items group by 1,2 order by 1,2;


-- ══════ db/성구암송_내용_60구절.sql ══════
-- =====================================================================
--  📜 성구암송 내용 ① — 네비게이토 주제별 성구암송 (TMS) 60구절
--
--  다섯 묶음(A~E) × 주제 여섯 × 두 구절 = 60구절.
--  한글(개역개정)과 영어(NIV)를 따로 담습니다. 같은 구절이라도 줄을
--  따로 두어, 학생이 한글로 외운 것과 영어로 외운 것을 각각 체크합니다.
--
--  한글 본문은 보내주신 그대로 넣었습니다.
--
--  ⚠️ 영어(NIV) 본문은 제가 적은 것입니다. 아이들이 이 글로 외우게
--     되니 한 번 훑어봐 주세요. 다르면 학사 → 성구암송 → 항목 관리
--     에서 고칠 수 있습니다.
--
--  ※ db/성구암송_DB설치.sql 과 db/성구암송_분류언어_DB설치.sql 을
--    먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
--
--  Scripture quotations marked NIV are taken from the Holy Bible,
--  New International Version®, NIV®. Copyright © 1973, 1978, 1984,
--  2011 by Biblica, Inc.® Used by permission. All rights reserved
--  worldwide.
-- =====================================================================

delete from public.memory_items where kind = 'verse' and community_id is null;

insert into public.memory_items (kind, lang, no, title, body, series, topic, community_id, sort) values
  ('verse', 'ko', 1, '고린도후서 5:17', '그런즉 누구든지 그리스도 안에 있으면 새로운 피조물이라 이전 것은 지나갔으니 보라 새 것이 되었도다', 'A. 새로운 삶', '중심되신 그리스도', null, 1),
  ('verse', 'en', 1, '2 Corinthians 5:17', 'Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!', 'A. The New Life', 'Christ the Center', null, 1),
  ('verse', 'ko', 2, '갈라디아서 2:20', '내가 그리스도와 함께 십자가에 못 박혔나니 그런즉 이제는 내가 사는 것이 아니요 오직 내 안에 그리스도께서 사시는 것이라 이제 내가 육체 가운데 사는 것은 나를 사랑하사 나를 위하여 자기 자신을 버리신 하나님의 아들을 믿는 믿음 안에서 사는 것이라', 'A. 새로운 삶', '중심되신 그리스도', null, 2),
  ('verse', 'en', 2, 'Galatians 2:20', 'I have been crucified with Christ and I no longer live, but Christ lives in me. The life I now live in the body, I live by faith in the Son of God, who loved me and gave himself for me.', 'A. The New Life', 'Christ the Center', null, 2),
  ('verse', 'ko', 3, '로마서 12:1', '그러므로 형제들아 내가 하나님의 모든 자비하심으로 너희를 권하노니 너희 몸을 하나님이 기뻐하시는 거룩한 산 제물로 드리라 이는 너희가 드릴 영적 예배니라', 'A. 새로운 삶', '그리스도께 순종', null, 3),
  ('verse', 'en', 3, 'Romans 12:1', 'Therefore, I urge you, brothers and sisters, in view of God''s mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship.', 'A. The New Life', 'Obedience to Christ', null, 3),
  ('verse', 'ko', 4, '요한복음 14:21', '나의 계명을 지키는 자라야 나를 사랑하는 자니 나를 사랑하는 자는 내 아버지께 사랑을 받을 것이요 나도 그를 사랑하여 그에게 나를 나타내리라', 'A. 새로운 삶', '그리스도께 순종', null, 4),
  ('verse', 'en', 4, 'John 14:21', 'Whoever has my commands and keeps them is the one who loves me. The one who loves me will be loved by my Father, and I too will love them and show myself to them.', 'A. The New Life', 'Obedience to Christ', null, 4),
  ('verse', 'ko', 5, '디모데후서 3:16', '모든 성경은 하나님의 감동으로 된 것으로 교훈과 책망과 바르게 함과 의로 교육하기에 유익하니', 'A. 새로운 삶', '말씀', null, 5),
  ('verse', 'en', 5, '2 Timothy 3:16', 'All Scripture is God-breathed and is useful for teaching, rebuking, correcting and training in righteousness,', 'A. The New Life', 'The Word', null, 5),
  ('verse', 'ko', 6, '여호수아 1:8', '이 율법책을 네 입에서 떠나지 말게 하며 주야로 그것을 묵상하여 그 안에 기록된 대로 다 지켜 행하라 그리하면 네 길이 평탄하게 될 것이며 네가 형통하리라', 'A. 새로운 삶', '말씀', null, 6),
  ('verse', 'en', 6, 'Joshua 1:8', 'Keep this Book of the Law always on your lips; meditate on it day and night, so that you may be careful to do everything written in it. Then you will be prosperous and successful.', 'A. The New Life', 'The Word', null, 6),
  ('verse', 'ko', 7, '요한복음 15:7', '너희가 내 안에 거하고 내 말이 너희 안에 거하면 무엇이든지 원하는 대로 구하라 그리하면 이루리라', 'A. 새로운 삶', '기도', null, 7),
  ('verse', 'en', 7, 'John 15:7', 'If you remain in me and my words remain in you, ask whatever you wish, and it will be done for you.', 'A. The New Life', 'Prayer', null, 7),
  ('verse', 'ko', 8, '빌립보서 4:6-7', '아무 것도 염려하지 말고 다만 모든 일에 기도와 간구로, 너희 구할 것을 감사함으로 하나님께 아뢰라
그리하면 모든 지각에 뛰어난 하나님의 평강이 그리스도 예수 안에서 너희 마음과 생각을 지키시리라', 'A. 새로운 삶', '기도', null, 8),
  ('verse', 'en', 8, 'Philippians 4:6-7', 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.
And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.', 'A. The New Life', 'Prayer', null, 8),
  ('verse', 'ko', 9, '마태복음 18:20', '두세 사람이 내 이름으로 모인 곳에는 나도 그들 중에 있느니라', 'A. 새로운 삶', '교제', null, 9),
  ('verse', 'en', 9, 'Matthew 18:20', 'For where two or three gather in my name, there am I with them.', 'A. The New Life', 'Fellowship', null, 9),
  ('verse', 'ko', 10, '히브리서 10:24-25', '서로 돌아보아 사랑과 선행을 격려하며
모이기를 폐하는 어떤 사람들의 습관과 같이 하지 말고 오직 권하여 그 날이 가까움을 볼수록 더욱 그리하자', 'A. 새로운 삶', '교제', null, 10),
  ('verse', 'en', 10, 'Hebrews 10:24-25', 'And let us consider how we may spur one another on toward love and good deeds,
not giving up meeting together, as some are in the habit of doing, but encouraging one another—and all the more as you see the Day approaching.', 'A. The New Life', 'Fellowship', null, 10),
  ('verse', 'ko', 11, '마태복음 4:19', '말씀하시되 나를 따라오라 내가 너희를 사람을 낚는 어부가 되게 하리라 하시니', 'A. 새로운 삶', '증거', null, 11),
  ('verse', 'en', 11, 'Matthew 4:19', '"Come, follow me," Jesus said, "and I will send you out to fish for people."', 'A. The New Life', 'Witnessing', null, 11),
  ('verse', 'ko', 12, '로마서 1:16', '내가 복음을 부끄러워하지 아니하노니 이 복음은 모든 믿는 자에게 구원을 주시는 하나님의 능력이 됨이라 먼저는 유대인에게요 그리고 헬라인에게로다', 'A. 새로운 삶', '증거', null, 12),
  ('verse', 'en', 12, 'Romans 1:16', 'For I am not ashamed of the gospel, because it is the power of God that brings salvation to everyone who believes: first to the Jew, then to the Gentile.', 'A. The New Life', 'Witnessing', null, 12),
  ('verse', 'ko', 13, '로마서 3:23', '모든 사람이 죄를 범하였으매 하나님의 영광에 이르지 못하더니', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 13),
  ('verse', 'en', 13, 'Romans 3:23', 'for all have sinned and fall short of the glory of God,', 'B. Proclaim Christ', 'All Have Sinned', null, 13),
  ('verse', 'ko', 14, '이사야 53:6', '우리는 다 양 같아서 그릇 행하여 각기 제 길로 갔거늘 여호와께서는 우리 모두의 죄악을 그에게 담당시키셨도다', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 14),
  ('verse', 'en', 14, 'Isaiah 53:6', 'We all, like sheep, have gone astray, each of us has turned to our own way; and the LORD has laid on him the iniquity of us all.', 'B. Proclaim Christ', 'All Have Sinned', null, 14),
  ('verse', 'ko', 15, '로마서 6:23', '죄의 삯은 사망이요 하나님의 은사는 그리스도 예수 우리 주 안에 있는 영생이니라', 'B. 그리스도를 전파함', '죄의 형벌', null, 15),
  ('verse', 'en', 15, 'Romans 6:23', 'For the wages of sin is death, but the gift of God is eternal life in Christ Jesus our Lord.', 'B. Proclaim Christ', 'Sin''s Penalty', null, 15),
  ('verse', 'ko', 16, '히브리서 9:27', '한번 죽는 것은 사람에게 정해진 것이요 그 후에는 심판이 있으리니', 'B. 그리스도를 전파함', '죄의 형벌', null, 16),
  ('verse', 'en', 16, 'Hebrews 9:27', 'Just as people are destined to die once, and after that to face judgment,', 'B. Proclaim Christ', 'Sin''s Penalty', null, 16),
  ('verse', 'ko', 17, '로마서 5:8', '우리가 아직 죄인 되었을 때에 그리스도께서 우리를 위하여 죽으심으로 하나님께서 우리에 대한 자기의 사랑을 확증하셨느니라', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 17),
  ('verse', 'en', 17, 'Romans 5:8', 'But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 17),
  ('verse', 'ko', 18, '베드로전서 3:18', '그리스도께서도 단번에 죄를 위하여 죽으사 의인으로서 불의한 자를 대신하셨으니 이는 우리를 하나님 앞으로 인도하려 하심이라 육체로는 죽임을 당하시고 영으로는 살리심을 받으셨으니', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 18),
  ('verse', 'en', 18, '1 Peter 3:18', 'For Christ also suffered once for sins, the righteous for the unrighteous, to bring you to God. He was put to death in the body but made alive in the Spirit.', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 18),
  ('verse', 'ko', 19, '에베소서 2:8-9', '너희는 그 은혜에 의하여 믿음으로 말미암아 구원을 받았으니 이것은 너희에게서 난 것이 아니요 하나님의 선물이라
행위에서 난 것이 아니니 이는 누구든지 자랑하지 못하게 함이라', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 19),
  ('verse', 'en', 19, 'Ephesians 2:8-9', 'For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—
not by works, so that no one can boast.', 'B. Proclaim Christ', 'Salvation Not by Works', null, 19),
  ('verse', 'ko', 20, '디도서 3:5', '우리를 구원하시되 우리가 행한 바 의로운 행위로 말미암지 아니하고 오직 그의 긍휼하심을 따라 중생의 씻음과 성령의 새롭게 하심으로 하셨나니', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 20),
  ('verse', 'en', 20, 'Titus 3:5', 'he saved us, not because of righteous things we had done, but because of his mercy. He saved us through the washing of rebirth and renewal by the Holy Spirit,', 'B. Proclaim Christ', 'Salvation Not by Works', null, 20),
  ('verse', 'ko', 21, '요한복음 1:12', '영접하는 자 곧 그 이름을 믿는 자들에게는 하나님의 자녀가 되는 권세를 주셨으니', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 21),
  ('verse', 'en', 21, 'John 1:12', 'Yet to all who did receive him, to those who believed in his name, he gave the right to become children of God—', 'B. Proclaim Christ', 'Must Receive Christ', null, 21),
  ('verse', 'ko', 22, '요한계시록 3:20', '볼지어다 내가 문 밖에 서서 두드리노니 누구든지 내 음성을 듣고 문을 열면 내가 그에게로 들어가 그와 더불어 먹고 그는 나와 더불어 먹으리라', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 22),
  ('verse', 'en', 22, 'Revelation 3:20', 'Here I am! I stand at the door and knock. If anyone hears my voice and opens the door, I will come in and eat with that person, and they with me.', 'B. Proclaim Christ', 'Must Receive Christ', null, 22),
  ('verse', 'ko', 23, '요한일서 5:13', '내가 하나님의 아들의 이름을 믿는 너희에게 이것을 쓰는 것은 너희로 하여금 너희에게 영생이 있음을 알게 하려 함이라', 'B. 그리스도를 전파함', '구원의 확신', null, 23),
  ('verse', 'en', 23, '1 John 5:13', 'I write these things to you who believe in the name of the Son of God so that you may know that you have eternal life.', 'B. Proclaim Christ', 'Assurance of Salvation', null, 23),
  ('verse', 'ko', 24, '요한복음 5:24', '내가 진실로 진실로 너희에게 이르노니 내 말을 듣고 또 나 보내신 이를 믿는 자는 영생을 얻었고 심판에 이르지 아니하나니 사망에서 생명으로 옮겼느니라', 'B. 그리스도를 전파함', '구원의 확신', null, 24),
  ('verse', 'en', 24, 'John 5:24', 'Very truly I tell you, whoever hears my word and believes him who sent me has eternal life and will not be judged but has crossed over from death to life.', 'B. Proclaim Christ', 'Assurance of Salvation', null, 24),
  ('verse', 'ko', 25, '고린도전서 3:16', '너희는 너희가 하나님의 성전인 것과 하나님의 성령이 너희 안에 계시는 것을 알지 못하느냐', 'C. 하나님을 의뢰함', '성령', null, 25),
  ('verse', 'en', 25, '1 Corinthians 3:16', 'Don''t you know that you yourselves are God''s temple and that God''s Spirit dwells in your midst?', 'C. Rely on God''s Resources', 'His Spirit', null, 25),
  ('verse', 'ko', 26, '고린도전서 2:12', '우리가 세상의 영을 받지 아니하고 오직 하나님으로부터 온 영을 받았으니 이는 우리로 하여금 하나님께서 우리에게 은혜로 주신 것들을 알게 하려 하심이라', 'C. 하나님을 의뢰함', '성령', null, 26),
  ('verse', 'en', 26, '1 Corinthians 2:12', 'What we have received is not the spirit of the world, but the Spirit who is from God, so that we may understand what God has freely given us.', 'C. Rely on God''s Resources', 'His Spirit', null, 26),
  ('verse', 'ko', 27, '이사야 41:10', '두려워하지 말라 내가 너와 함께 함이라 놀라지 말라 나는 네 하나님이 됨이라 내가 너를 굳세게 하리라 참으로 너를 도와 주리라 참으로 나의 의로운 오른손으로 너를 붙들리라', 'C. 하나님을 의뢰함', '능력', null, 27),
  ('verse', 'en', 27, 'Isaiah 41:10', 'So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.', 'C. Rely on God''s Resources', 'His Strength', null, 27),
  ('verse', 'ko', 28, '빌립보서 4:13', '내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라', 'C. 하나님을 의뢰함', '능력', null, 28),
  ('verse', 'en', 28, 'Philippians 4:13', 'I can do all this through him who gives me strength.', 'C. Rely on God''s Resources', 'His Strength', null, 28),
  ('verse', 'ko', 29, '예레미야애가 3:22-23', '여호와의 인자와 긍휼이 무궁하시므로 우리가 진멸되지 아니함이니이다
이것들이 아침마다 새로우니 주의 성실하심이 크시도소이다', 'C. 하나님을 의뢰함', '성실', null, 29),
  ('verse', 'en', 29, 'Lamentations 3:22-23', 'Because of the LORD''s great love we are not consumed, for his compassions never fail.
They are new every morning; great is your faithfulness.', 'C. Rely on God''s Resources', 'His Faithfulness', null, 29),
  ('verse', 'ko', 30, '민수기 23:19', '하나님은 사람이 아니시니 거짓말을 하지 않으시고 인생이 아니시니 후회가 없으시도다 어찌 그 말씀하신 바를 행하지 않으시며 하신 말씀을 실행하지 않으시랴', 'C. 하나님을 의뢰함', '성실', null, 30),
  ('verse', 'en', 30, 'Numbers 23:19', 'God is not human, that he should lie, not a human being, that he should change his mind. Does he speak and then not act? Does he promise and not fulfill?', 'C. Rely on God''s Resources', 'His Faithfulness', null, 30),
  ('verse', 'ko', 31, '이사야 26:3', '주께서 심지가 견고한 자를 평강하고 평강하도록 지키시리니 이는 그가 주를 신뢰함이니이다', 'C. 하나님을 의뢰함', '평안', null, 31),
  ('verse', 'en', 31, 'Isaiah 26:3', 'You will keep in perfect peace those whose minds are steadfast, because they trust in you.', 'C. Rely on God''s Resources', 'His Peace', null, 31),
  ('verse', 'ko', 32, '베드로전서 5:7', '너희 염려를 다 주께 맡기라 이는 그가 너희를 돌보심이라', 'C. 하나님을 의뢰함', '평안', null, 32),
  ('verse', 'en', 32, '1 Peter 5:7', 'Cast all your anxiety on him because he cares for you.', 'C. Rely on God''s Resources', 'His Peace', null, 32),
  ('verse', 'ko', 33, '로마서 8:32', '자기 아들을 아끼지 아니하시고 우리 모든 사람을 위하여 내주신 이가 어찌 그 아들과 함께 모든 것을 우리에게 주시지 아니하겠느냐', 'C. 하나님을 의뢰함', '공급', null, 33),
  ('verse', 'en', 33, 'Romans 8:32', 'He who did not spare his own Son, but gave him up for us all—how will he not also, along with him, graciously give us all things?', 'C. Rely on God''s Resources', 'His Provision', null, 33),
  ('verse', 'ko', 34, '빌립보서 4:19', '나의 하나님이 그리스도 예수 안에서 영광 가운데 그 풍성한 대로 너희 모든 쓸 것을 채우시리라', 'C. 하나님을 의뢰함', '공급', null, 34),
  ('verse', 'en', 34, 'Philippians 4:19', 'And my God will meet all your needs according to the riches of his glory in Christ Jesus.', 'C. Rely on God''s Resources', 'His Provision', null, 34),
  ('verse', 'ko', 35, '히브리서 2:18', '그가 시험을 받아 고난을 당하셨은즉 시험 받는 자들을 능히 도우실 수 있느니라', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 35),
  ('verse', 'en', 35, 'Hebrews 2:18', 'Because he himself suffered when he was tempted, he is able to help those who are being tempted.', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 35),
  ('verse', 'ko', 36, '시편 119:9,11', '청년이 무엇으로 그의 행실을 깨끗하게 하리이까 주의 말씀만 지킬 따름이니이다
내가 주께 범죄하지 아니하려 하여 주의 말씀을 내 마음에 두었나이다', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 36),
  ('verse', 'en', 36, 'Psalm 119:9,11', 'How can a young person stay on the path of purity? By living according to your word.
I have hidden your word in my heart that I might not sin against you.', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 36),
  ('verse', 'ko', 37, '마태복음 6:33', '그런즉 너희는 먼저 그의 나라와 그의 의를 구하라 그리하면 이 모든 것을 너희에게 더하시리라', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 37),
  ('verse', 'en', 37, 'Matthew 6:33', 'But seek first his kingdom and his righteousness, and all these things will be given to you as well.', 'D. Be Christ''s Disciple', 'Put Christ First', null, 37),
  ('verse', 'ko', 38, '누가복음 9:23', '또 무리에게 이르시되 아무든지 나를 따라오려거든 자기를 부인하고 날마다 제 십자가를 지고 나를 따를 것이니라', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 38),
  ('verse', 'en', 38, 'Luke 9:23', 'Then he said to them all: "Whoever wants to be my disciple must deny themselves and take up their cross daily and follow me."', 'D. Be Christ''s Disciple', 'Put Christ First', null, 38),
  ('verse', 'ko', 39, '요한일서 2:15-16', '이 세상이나 세상에 있는 것들을 사랑하지 말라 누구든지 세상을 사랑하면 아버지의 사랑이 그 안에 있지 아니하니
이는 세상에 있는 모든 것이 육신의 정욕과 안목의 정욕과 이생의 자랑이니 다 아버지께로부터 온 것이 아니요 세상으로부터 온 것이라', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 39),
  ('verse', 'en', 39, '1 John 2:15-16', 'Do not love the world or anything in the world. If anyone loves the world, love for the Father is not in them.
For everything in the world—the lust of the flesh, the lust of the eyes, and the pride of life—comes not from the Father but from the world.', 'D. Be Christ''s Disciple', 'Separate from the World', null, 39),
  ('verse', 'ko', 40, '로마서 12:2', '너희는 이 세대를 본받지 말고 오직 마음을 새롭게 함으로 변화를 받아 하나님의 선하시고 기뻐하시고 온전하신 뜻이 무엇인지 분별하도록 하라', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 40),
  ('verse', 'en', 40, 'Romans 12:2', 'Do not conform to the pattern of this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what God''s will is—his good, pleasing and perfect will.', 'D. Be Christ''s Disciple', 'Separate from the World', null, 40),
  ('verse', 'ko', 41, '고린도전서 15:58', '그러므로 내 사랑하는 형제들아 견실하며 흔들리지 말고 항상 주의 일에 더욱 힘쓰는 자들이 되라 이는 너희 수고가 주 안에서 헛되지 않은 줄 앎이라', 'D. 그리스도 제자의 자격', '견고함', null, 41),
  ('verse', 'en', 41, '1 Corinthians 15:58', 'Therefore, my dear brothers and sisters, stand firm. Let nothing move you. Always give yourselves fully to the work of the Lord, because you know that your labor in the Lord is not in vain.', 'D. Be Christ''s Disciple', 'Steadfast', null, 41),
  ('verse', 'ko', 42, '히브리서 12:3', '너희가 피곤하여 낙심하지 않기 위하여 죄인들이 이같이 자기에게 거역한 일을 참으신 이를 생각하라', 'D. 그리스도 제자의 자격', '견고함', null, 42),
  ('verse', 'en', 42, 'Hebrews 12:3', 'Consider him who endured such opposition from sinners, so that you will not grow weary and lose heart.', 'D. Be Christ''s Disciple', 'Steadfast', null, 42),
  ('verse', 'ko', 43, '마가복음 10:45', '인자가 온 것은 섬김을 받으려 함이 아니라 도리어 섬기려 하고 자기 목숨을 많은 사람의 대속물로 주려 함이니라', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 43),
  ('verse', 'en', 43, 'Mark 10:45', 'For even the Son of Man did not come to be served, but to serve, and to give his life as a ransom for many.', 'D. Be Christ''s Disciple', 'Serve Others', null, 43),
  ('verse', 'ko', 44, '고린도후서 4:5', '우리는 우리를 전파하는 것이 아니라 오직 그리스도 예수의 주 되신 것과 또 예수를 위하여 우리가 너희의 종 된 것을 전파함이라', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 44),
  ('verse', 'en', 44, '2 Corinthians 4:5', 'For what we preach is not ourselves, but Jesus Christ as Lord, and ourselves as your servants for Jesus'' sake.', 'D. Be Christ''s Disciple', 'Serve Others', null, 44),
  ('verse', 'ko', 45, '잠언 3:9-10', '네 재물과 네 소산물의 처음 익은 열매로 여호와를 공경하라
그리하면 네 창고가 가득히 차고 네 포도즙 틀에 새 포도즙이 넘치리라', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 45),
  ('verse', 'en', 45, 'Proverbs 3:9-10', 'Honor the LORD with your wealth, with the firstfruits of all your crops;
then your barns will be filled to overflowing, and your vats will brim over with new wine.', 'D. Be Christ''s Disciple', 'Give Generously', null, 45),
  ('verse', 'ko', 46, '고린도후서 9:6-7', '이것이 곧 적게 심는 자는 적게 거두고 많이 심는 자는 많이 거둔다 하는 말이로다
각각 그 마음에 정한 대로 할 것이요 인색함으로나 억지로 하지 말지니 하나님은 즐겨 내는 자를 사랑하시느니라', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 46),
  ('verse', 'en', 46, '2 Corinthians 9:6-7', 'Remember this: Whoever sows sparingly will also reap sparingly, and whoever sows generously will also reap generously.
Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.', 'D. Be Christ''s Disciple', 'Give Generously', null, 46),
  ('verse', 'ko', 47, '사도행전 1:8', '오직 성령이 너희에게 임하시면 너희가 권능을 받고 예루살렘과 온 유대와 사마리아와 땅 끝까지 이르러 내 증인이 되리라 하시니라', 'D. 그리스도 제자의 자격', '세계 비전', null, 47),
  ('verse', 'en', 47, 'Acts 1:8', 'But you will receive power when the Holy Spirit comes on you; and you will be my witnesses in Jerusalem, and in all Judea and Samaria, and to the ends of the earth.', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 47),
  ('verse', 'ko', 48, '마태복음 28:19-20', '그러므로 너희는 가서 모든 민족을 제자로 삼아 아버지와 아들과 성령의 이름으로 세례를 베풀고
내가 너희에게 분부한 모든 것을 가르쳐 지키게 하라 볼지어다 내가 세상 끝날까지 너희와 항상 함께 있으리라 하시니라', 'D. 그리스도 제자의 자격', '세계 비전', null, 48),
  ('verse', 'en', 48, 'Matthew 28:19-20', 'Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit,
and teaching them to obey everything I have commanded you. And surely I am with you always, to the very end of the age.', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 48),
  ('verse', 'ko', 49, '요한복음 13:34-35', '새 계명을 너희에게 주노니 서로 사랑하라 내가 너희를 사랑한 것 같이 너희도 서로 사랑하라
너희가 서로 사랑하면 이로써 모든 사람이 너희가 내 제자인 줄 알리라', 'E. 그리스도를 닮아감', '사랑', null, 49),
  ('verse', 'en', 49, 'John 13:34-35', 'A new command I give you: Love one another. As I have loved you, so you must love one another.
By this everyone will know that you are my disciples, if you love one another.', 'E. Grow in Christlikeness', 'Love', null, 49),
  ('verse', 'ko', 50, '요한일서 3:18', '자녀들아 우리가 말과 혀로만 사랑하지 말고 행함과 진실함으로 하자', 'E. 그리스도를 닮아감', '사랑', null, 50),
  ('verse', 'en', 50, '1 John 3:18', 'Dear children, let us not love with words or speech but with actions and in truth.', 'E. Grow in Christlikeness', 'Love', null, 50),
  ('verse', 'ko', 51, '빌립보서 2:3-4', '아무 일에든지 다툼이나 허영으로 하지 말고 오직 겸손한 마음으로 각각 자기보다 남을 낫게 여기고
각각 자기 일을 돌볼뿐더러 또한 각각 다른 사람들의 일을 돌보아 나의 기쁨을 충만하게 하라', 'E. 그리스도를 닮아감', '겸손', null, 51),
  ('verse', 'en', 51, 'Philippians 2:3-4', 'Do nothing out of selfish ambition or vain conceit. Rather, in humility value others above yourselves,
not looking to your own interests but each of you to the interests of the others.', 'E. Grow in Christlikeness', 'Humility', null, 51),
  ('verse', 'ko', 52, '베드로전서 5:5-6', '젊은 자들아 이와 같이 장로들에게 순종하고 다 서로 겸손으로 허리를 동이라 하나님은 교만한 자를 대적하시되 겸손한 자들에게는 은혜를 주시느니라
그러므로 하나님의 능하신 손 아래에서 겸손하라 때가 되면 너희를 높이시리라', 'E. 그리스도를 닮아감', '겸손', null, 52),
  ('verse', 'en', 52, '1 Peter 5:5-6', 'In the same way, you who are younger, submit yourselves to your elders. All of you, clothe yourselves with humility toward one another, because, "God opposes the proud but shows favor to the humble."
Humble yourselves, therefore, under God''s mighty hand, that he may lift you up in due time.', 'E. Grow in Christlikeness', 'Humility', null, 52),
  ('verse', 'ko', 53, '에베소서 5:3', '음행과 온갖 더러운 것과 탐욕은 너희 중에서 그 이름조차도 부르지 말라 이는 성도에게 마땅한 바니라', 'E. 그리스도를 닮아감', '순결', null, 53),
  ('verse', 'en', 53, 'Ephesians 5:3', 'But among you there must not be even a hint of sexual immorality, or of any kind of impurity, or of greed, because these are improper for God''s holy people.', 'E. Grow in Christlikeness', 'Purity', null, 53),
  ('verse', 'ko', 54, '베드로전서 2:11', '사랑하는 자들아 거류민과 나그네 같은 너희를 권하노니 영혼을 거슬러 싸우는 육체의 정욕을 제어하라', 'E. 그리스도를 닮아감', '순결', null, 54),
  ('verse', 'en', 54, '1 Peter 2:11', 'Dear friends, I urge you, as foreigners and exiles, to abstain from sinful desires, which wage war against your soul.', 'E. Grow in Christlikeness', 'Purity', null, 54),
  ('verse', 'ko', 55, '레위기 19:11', '너희는 도둑질하지 말며 속이지 말며 서로 거짓말하지 말며', 'E. 그리스도를 닮아감', '정직', null, 55),
  ('verse', 'en', 55, 'Leviticus 19:11', 'Do not steal. Do not lie. Do not deceive one another.', 'E. Grow in Christlikeness', 'Honesty', null, 55),
  ('verse', 'ko', 56, '사도행전 24:16', '이것으로 말미암아 나도 하나님과 사람에 대하여 항상 양심에 거리낌이 없기를 힘쓰나이다', 'E. 그리스도를 닮아감', '정직', null, 56),
  ('verse', 'en', 56, 'Acts 24:16', 'So I strive always to keep my conscience clear before God and man.', 'E. Grow in Christlikeness', 'Honesty', null, 56),
  ('verse', 'ko', 57, '히브리서 11:6', '믿음이 없이는 하나님을 기쁘시게 하지 못하나니 하나님께 나아가는 자는 반드시 그가 계신 것과 또한 그가 자기를 찾는 자들에게 상 주시는 이심을 믿어야 할지니라', 'E. 그리스도를 닮아감', '믿음', null, 57),
  ('verse', 'en', 57, 'Hebrews 11:6', 'And without faith it is impossible to please God, because anyone who comes to him must believe that he exists and that he rewards those who earnestly seek him.', 'E. Grow in Christlikeness', 'Faith', null, 57),
  ('verse', 'ko', 58, '로마서 4:20-21', '믿음이 없어 하나님의 약속을 의심하지 않고 믿음으로 견고하여져서 하나님께 영광을 돌리며
약속하신 그것을 또한 능히 이루실 줄을 확신하였으니', 'E. 그리스도를 닮아감', '믿음', null, 58),
  ('verse', 'en', 58, 'Romans 4:20-21', 'Yet he did not waver through unbelief regarding the promise of God, but was strengthened in his faith and gave glory to God,
being fully persuaded that God had power to do what he had promised.', 'E. Grow in Christlikeness', 'Faith', null, 58),
  ('verse', 'ko', 59, '갈라디아서 6:9-10', '우리가 선을 행하되 낙심하지 말지니 포기하지 아니하면 때가 이르매 거두리라
그러므로 우리는 기회 있는 대로 모든 이에게 착한 일을 하되 더욱 믿음의 가정들에게 할지니라', 'E. 그리스도를 닮아감', '선행', null, 59),
  ('verse', 'en', 59, 'Galatians 6:9-10', 'Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.
Therefore, as we have opportunity, let us do good to all people, especially to those who belong to the family of believers.', 'E. Grow in Christlikeness', 'Good Works', null, 59),
  ('verse', 'ko', 60, '마태복음 5:16', '이같이 너희 빛이 사람 앞에 비치게 하여 그들로 너희 착한 행실을 보고 하늘에 계신 너희 아버지께 영광을 돌리게 하라', 'E. 그리스도를 닮아감', '선행', null, 60),
  ('verse', 'en', 60, 'Matthew 5:16', 'In the same way, let your light shine before others, that they may see your good deeds and glorify your Father in heaven.', 'E. Grow in Christlikeness', 'Good Works', null, 60);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select lang as "말", count(*) as "구절", count(distinct series) as "묶음", count(distinct topic) as "주제"
  from public.memory_items where kind='verse' group by 1 order by 1;

select series as "묶음", count(*) filter (where lang='ko') as "한글", count(*) filter (where lang='en') as "영어"
  from public.memory_items where kind='verse' group by 1 order by 1;


-- ══════ db/성구암송_내용_소교리문답.sql ══════
-- =====================================================================
--  📜 성구암송 내용 ② — 웨스트민스터 소교리문답 107문 (한글 · 영어)
--
--  영문은 1647년 웨스트민스터 총회 원문입니다. 저작권이 없는 글이라
--  그대로 싣습니다.
--
--  ⚠️ 한글은 제가 표준 번역을 바탕으로 적은 것입니다. 교회에서 쓰시는
--     번역본과 낱말이 다를 수 있습니다. 아이들이 이 글로 외우게
--     되니, 꼭 한 번 훑어보시고 다르면 고쳐 주세요.
--     고치는 길: 학사 → 성구암송 → 항목 관리 →
--     '여러 줄 한꺼번에 넣기' 에서 '모두 지우고 새로 넣기'
--
--  ※ db/성구암송_DB설치.sql 과 db/성구암송_분류언어_DB설치.sql 을
--    먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

delete from public.memory_items where kind = 'catechism' and community_id is null;

insert into public.memory_items (kind, lang, no, title, body, answer, community_id, sort) values
  ('catechism', 'ko', 1, '제1문', '사람의 제일 되는 목적이 무엇인가?', '사람의 제일 되는 목적은 하나님을 영화롭게 하고 영원토록 그를 즐거워하는 것이다.', null, 1),
  ('catechism', 'ko', 2, '제2문', '하나님께서 무슨 법칙을 주어 우리가 어떻게 그를 영화롭게 하고 즐거워할 것을 지시하셨는가?', '신구약 성경에 담긴 하나님의 말씀이 우리가 어떻게 그를 영화롭게 하고 즐거워할 것인지 지시하는 유일한 법칙이다.', null, 2),
  ('catechism', 'ko', 3, '제3문', '성경이 주로 가르치는 것이 무엇인가?', '성경이 주로 가르치는 것은 사람이 하나님에 대하여 무엇을 믿을 것과 하나님께서 사람에게 요구하시는 본분이 무엇인가 하는 것이다.', null, 3),
  ('catechism', 'ko', 4, '제4문', '하나님은 어떤 분이신가?', '하나님은 영이시니 그 존재와 지혜와 권능과 거룩하심과 공의와 인자하심과 진실하심이 무한하시고 영원하시며 불변하시다.', null, 4),
  ('catechism', 'ko', 5, '제5문', '하나님이 한 분 외에 또 있는가?', '오직 한 분 참되시고 살아 계신 하나님만 계시다.', null, 5),
  ('catechism', 'ko', 6, '제6문', '하나님의 신격에 몇 위가 계신가?', '하나님의 신격에 삼위가 계시니 곧 성부와 성자와 성령이시다. 이 삼위는 한 하나님이시요 본체는 하나이며 권능과 영광이 동등하시다.', null, 6),
  ('catechism', 'ko', 7, '제7문', '하나님의 작정이 무엇인가?', '하나님의 작정은 그의 뜻의 계획을 따라 자기 영광을 위하여 일어날 모든 일을 미리 정하신 영원한 목적이다.', null, 7),
  ('catechism', 'ko', 8, '제8문', '하나님이 그의 작정을 어떻게 실행하시는가?', '하나님은 창조와 섭리의 사역으로 그의 작정을 실행하신다.', null, 8),
  ('catechism', 'ko', 9, '제9문', '창조의 사역이 무엇인가?', '창조의 사역은 하나님이 엿새 동안에 말씀의 권능으로 모든 것을 무에서 만드시되 심히 좋게 만드신 것이다.', null, 9),
  ('catechism', 'ko', 10, '제10문', '하나님이 사람을 어떻게 창조하셨는가?', '하나님이 남자와 여자를 자기 형상대로 지식과 의와 거룩함으로 창조하시고 피조물을 다스리게 하셨다.', null, 10),
  ('catechism', 'ko', 11, '제11문', '하나님의 섭리의 사역이 무엇인가?', '하나님의 섭리의 사역은 그의 모든 피조물과 그들의 모든 행동을 가장 거룩하고 지혜롭고 능력 있게 보존하시고 다스리시는 것이다.', null, 11),
  ('catechism', 'ko', 12, '제12문', '하나님이 사람을 창조하신 후 그에게 어떤 특별한 섭리의 행위를 베푸셨는가?', '하나님이 사람을 창조하신 후에 생명의 언약을 세우시되 완전한 순종을 조건으로 하시고 선악을 알게 하는 나무의 열매를 먹지 말라 명하시며 어기면 죽으리라 하셨다.', null, 12),
  ('catechism', 'ko', 13, '제13문', '우리의 시조가 창조함을 받은 그 상태에 그대로 있었는가?', '우리의 시조는 자기의 자유의지에 맡겨졌으나 하나님께 범죄함으로 창조함을 받은 그 상태에서 타락하였다.', null, 13),
  ('catechism', 'ko', 14, '제14문', '죄가 무엇인가?', '죄는 하나님의 법에 순종하지 않거나 그것을 어기는 것이다.', null, 14),
  ('catechism', 'ko', 15, '제15문', '우리의 시조가 창조함을 받은 그 상태에서 타락하게 한 죄가 무엇인가?', '우리의 시조가 타락하게 된 죄는 금한 열매를 먹은 것이다.', null, 15),
  ('catechism', 'ko', 16, '제16문', '온 인류가 아담의 첫 범죄에 타락하였는가?', '아담과 맺은 언약은 그 자신뿐 아니라 그의 후손을 위한 것이므로 보통 생육법으로 그에게서 난 온 인류가 그의 첫 범죄에 그와 함께 범죄하고 타락하였다.', null, 16),
  ('catechism', 'ko', 17, '제17문', '타락은 인류를 어떤 상태에 빠지게 하였는가?', '타락은 인류를 죄와 비참한 상태에 빠지게 하였다.', null, 17),
  ('catechism', 'ko', 18, '제18문', '사람이 빠진 그 상태의 죄악성이 무엇인가?', '사람이 빠진 그 상태의 죄악성은 아담의 첫 죄의 죄책과 원래의 의의 결핍과 전 성품의 부패니 이것을 원죄라 하며 거기서 나오는 모든 자범죄이다.', null, 18),
  ('catechism', 'ko', 19, '제19문', '사람이 빠진 그 상태의 비참이 무엇인가?', '온 인류가 타락으로 하나님과의 교제를 잃고 그의 진노와 저주 아래 있어 이 세상의 모든 비참과 사망과 영원한 지옥의 고통을 당하게 되었다.', null, 19),
  ('catechism', 'ko', 20, '제20문', '하나님이 온 인류를 죄와 비참한 상태에서 멸망하도록 버려 두셨는가?', '하나님이 순전히 그의 기쁘신 뜻대로 영원 전에 어떤 사람들을 택하여 영생에 이르게 하시고 은혜 언약을 세우사 한 구속자로 말미암아 죄와 비참한 상태에서 건져내어 구원의 상태에 이르게 하셨다.', null, 20),
  ('catechism', 'ko', 21, '제21문', '하나님의 택하신 자의 구속자가 누구신가?', '하나님의 택하신 자의 유일한 구속자는 주 예수 그리스도시니 영원하신 하나님의 아들로서 사람이 되사 하나님이시며 사람이신 두 본성이 한 위에 계시며 영원토록 그러하시다.', null, 21),
  ('catechism', 'ko', 22, '제22문', '그리스도께서 하나님의 아들로서 어떻게 사람이 되셨는가?', '그리스도께서 참된 몸과 이성 있는 영혼을 취하사 성령의 능력으로 동정녀 마리아의 태에 잉태되어 나셨으되 죄는 없으시다.', null, 22),
  ('catechism', 'ko', 23, '제23문', '그리스도께서 우리의 구속자로서 무슨 직분을 행하시는가?', '그리스도께서 우리의 구속자로서 낮아지심과 높아지심의 두 상태에서 선지자와 제사장과 왕의 직분을 행하신다.', null, 23),
  ('catechism', 'ko', 24, '제24문', '그리스도께서 어떻게 선지자의 직분을 행하시는가?', '그리스도께서 그의 말씀과 성령으로 우리 구원을 위한 하나님의 뜻을 계시하심으로 선지자의 직분을 행하신다.', null, 24),
  ('catechism', 'ko', 25, '제25문', '그리스도께서 어떻게 제사장의 직분을 행하시는가?', '그리스도께서 하나님의 공의를 만족시키고 우리를 하나님과 화목하게 하려고 자신을 단번에 제물로 드리시고 우리를 위하여 계속 간구하심으로 제사장의 직분을 행하신다.', null, 25),
  ('catechism', 'ko', 26, '제26문', '그리스도께서 어떻게 왕의 직분을 행하시는가?', '그리스도께서 우리를 자기에게 복종하게 하시고 다스리시며 보호하시고 그와 우리의 모든 원수를 제어하시고 정복하심으로 왕의 직분을 행하신다.', null, 26),
  ('catechism', 'ko', 27, '제27문', '그리스도의 낮아지심이 무엇인가?', '그리스도의 낮아지심은 그가 비천한 처지에 나시고 율법 아래 나시며 이 세상의 비참과 하나님의 진노와 십자가의 저주받은 죽음을 당하시고 장사되어 얼마 동안 사망의 권세 아래 계신 것이다.', null, 27),
  ('catechism', 'ko', 28, '제28문', '그리스도의 높아지심이 무엇인가?', '그리스도의 높아지심은 그가 제삼일에 죽은 자 가운데서 살아나시고 하늘에 오르사 하나님 아버지 우편에 앉으시며 마지막 날에 세상을 심판하러 오시는 것이다.', null, 28),
  ('catechism', 'ko', 29, '제29문', '우리가 어떻게 그리스도의 사신 구속에 참여하는가?', '우리가 그리스도께서 사신 구속에 참여하는 것은 성령께서 그것을 우리에게 효력 있게 적용하심으로 되는 것이다.', null, 29),
  ('catechism', 'ko', 30, '제30문', '성령께서 어떻게 그리스도의 사신 구속을 우리에게 적용하시는가?', '성령께서 우리 안에 믿음을 일으키시고 그 믿음으로 우리를 효력 있게 부르실 때에 그리스도와 연합하게 하심으로 그 구속을 우리에게 적용하신다.', null, 30),
  ('catechism', 'ko', 31, '제31문', '효력 있는 부르심이 무엇인가?', '효력 있는 부르심은 하나님의 성령의 사역이니 우리로 죄와 비참을 깨닫게 하시고 마음을 밝혀 그리스도를 알게 하시며 의지를 새롭게 하사 복음에 값없이 주시는 예수 그리스도를 기꺼이 영접하게 하심이다.', null, 31),
  ('catechism', 'ko', 32, '제32문', '효력 있게 부르심을 받은 자가 이 세상에서 무슨 유익에 참여하는가?', '효력 있게 부르심을 받은 자는 이 세상에서 칭의와 양자됨과 성화와 그에 따르는 여러 유익에 참여한다.', null, 32),
  ('catechism', 'ko', 33, '제33문', '칭의가 무엇인가?', '칭의는 하나님의 값없이 주시는 은혜의 행위니 우리의 모든 죄를 사하시고 우리를 그 앞에서 의롭다 하여 받아 주심이다. 이는 오직 그리스도의 의 때문이며 믿음으로만 받는다.', null, 33),
  ('catechism', 'ko', 34, '제34문', '양자됨이 무엇인가?', '양자됨은 하나님의 값없이 주시는 은혜의 행위니 우리가 하나님의 아들들의 수에 들고 그의 모든 특권에 참여할 권리를 얻는 것이다.', null, 34),
  ('catechism', 'ko', 35, '제35문', '성화가 무엇인가?', '성화는 하나님의 값없이 주시는 은혜의 사역이니 우리가 하나님의 형상을 따라 전인이 새롭게 되고 점점 죄에 대하여 죽고 의에 대하여 살게 되는 것이다.', null, 35),
  ('catechism', 'ko', 36, '제36문', '칭의와 양자됨과 성화에 따르는 유익이 무엇인가?', '이 세상에서 따르는 유익은 하나님의 사랑을 확신함과 양심의 평안과 성령 안에서의 기쁨과 은혜의 더함과 끝까지 견디는 것이다.', null, 36),
  ('catechism', 'ko', 37, '제37문', '신자가 죽을 때에 그리스도에게서 무슨 유익을 받는가?', '신자의 영혼은 죽을 때에 완전히 거룩하게 되어 곧 영광에 들어가고 그 몸은 여전히 그리스도와 연합하여 부활 때까지 무덤에서 쉰다.', null, 37),
  ('catechism', 'ko', 38, '제38문', '신자가 부활 때에 그리스도에게서 무슨 유익을 받는가?', '신자는 부활 때에 영광 중에 다시 살아나서 심판 날에 공개적으로 인정받고 무죄 선언을 받으며 영원토록 하나님을 온전히 즐거워하는 복을 누린다.', null, 38),
  ('catechism', 'ko', 39, '제39문', '하나님이 사람에게 요구하시는 본분이 무엇인가?', '하나님이 사람에게 요구하시는 본분은 그의 계시하신 뜻에 순종하는 것이다.', null, 39),
  ('catechism', 'ko', 40, '제40문', '하나님이 처음에 사람에게 순종의 법칙으로 무엇을 계시하셨는가?', '하나님이 처음에 사람에게 순종의 법칙으로 계시하신 것은 도덕법이다.', null, 40),
  ('catechism', 'ko', 41, '제41문', '도덕법이 어디에 요약되어 있는가?', '도덕법은 십계명에 요약되어 있다.', null, 41),
  ('catechism', 'ko', 42, '제42문', '십계명의 대요가 무엇인가?', '십계명의 대요는 우리 마음과 뜻과 목숨과 힘을 다하여 주 우리 하나님을 사랑하고 네 이웃을 네 몸과 같이 사랑하라는 것이다.', null, 42),
  ('catechism', 'ko', 43, '제43문', '십계명의 서언이 무엇인가?', '십계명의 서언은 ''나는 너를 애굽 땅 종 되었던 집에서 인도하여 낸 네 하나님 여호와니라'' 하신 말씀이다.', null, 43),
  ('catechism', 'ko', 44, '제44문', '십계명의 서언이 우리에게 무엇을 가르치는가?', '십계명의 서언은 하나님이 주님이시요 우리의 하나님이시며 구속자가 되시므로 우리가 그의 모든 계명을 지킬 의무가 있음을 가르친다.', null, 44),
  ('catechism', 'ko', 45, '제45문', '제1계명이 무엇인가?', '제1계명은 ''너는 나 외에는 다른 신들을 네게 두지 말라''이다.', null, 45),
  ('catechism', 'ko', 46, '제46문', '제1계명이 무엇을 요구하는가?', '제1계명은 하나님을 홀로 참 하나님이시요 우리의 하나님으로 알고 인정하며 그에 합당하게 예배하고 영화롭게 할 것을 요구한다.', null, 46),
  ('catechism', 'ko', 47, '제47문', '제1계명이 무엇을 금하는가?', '제1계명은 참 하나님을 하나님과 우리의 하나님으로 부인하거나 예배하지 않거나 영화롭게 하지 않는 것과 오직 하나님께만 돌릴 예배와 영광을 다른 것에 돌리는 것을 금한다.', null, 47),
  ('catechism', 'ko', 48, '제48문', '제1계명의 ''나 외에는''이라는 말이 우리에게 특별히 무엇을 가르치는가?', '''나 외에는''이라는 말은 만물을 보시는 하나님께서 다른 신을 두는 죄를 보시고 심히 불쾌히 여기심을 가르친다.', null, 48),
  ('catechism', 'ko', 49, '제49문', '제2계명이 무엇인가?', '제2계명은 ''너를 위하여 새긴 우상을 만들지 말고 또 위로 하늘에 있는 것이나 아래로 땅에 있는 것이나 땅 아래 물속에 있는 것의 어떤 형상도 만들지 말며 그것들에게 절하지 말며 그것들을 섬기지 말라'' 하신 말씀이다.', null, 49),
  ('catechism', 'ko', 50, '제50문', '제2계명이 무엇을 요구하는가?', '제2계명은 하나님께서 그의 말씀에 정하신 종교적 예배와 규례를 그대로 받아 지키고 순전하게 보존할 것을 요구한다.', null, 50),
  ('catechism', 'ko', 51, '제51문', '제2계명이 무엇을 금하는가?', '제2계명은 형상으로 하나님을 예배하거나 그의 말씀에 정하지 아니한 다른 방법으로 예배하는 것을 금한다.', null, 51),
  ('catechism', 'ko', 52, '제52문', '제2계명에 붙인 이유가 무엇인가?', '제2계명에 붙인 이유는 하나님이 우리를 주관하시는 주권과 우리에 대한 소유권과 그의 예배에 대한 열심이다.', null, 52),
  ('catechism', 'ko', 53, '제53문', '제3계명이 무엇인가?', '제3계명은 ''너는 네 하나님 여호와의 이름을 망령되게 부르지 말라'' 하신 말씀이다.', null, 53),
  ('catechism', 'ko', 54, '제54문', '제3계명이 무엇을 요구하는가?', '제3계명은 하나님의 이름과 칭호와 속성과 규례와 말씀과 사역을 거룩하고 경건하게 쓸 것을 요구한다.', null, 54),
  ('catechism', 'ko', 55, '제55문', '제3계명이 무엇을 금하는가?', '제3계명은 하나님이 자기를 알리신 모든 것을 더럽히거나 남용하는 것을 금한다.', null, 55),
  ('catechism', 'ko', 56, '제56문', '제3계명에 붙인 이유가 무엇인가?', '제3계명에 붙인 이유는 이 계명을 어기는 자가 사람의 벌은 피할지라도 주 우리 하나님은 그의 공의로운 심판을 면하게 하지 않으신다는 것이다.', null, 56),
  ('catechism', 'ko', 57, '제57문', '제4계명이 무엇인가?', '제4계명은 ''안식일을 기억하여 거룩하게 지키라'' 하신 말씀이다.', null, 57),
  ('catechism', 'ko', 58, '제58문', '제4계명이 무엇을 요구하는가?', '제4계명은 하나님께서 그의 말씀에 정하신 때를 거룩하게 지킬 것을 요구하니 곧 이레 중 하루를 온전히 하나님께 거룩한 안식일로 지키는 것이다.', null, 58),
  ('catechism', 'ko', 59, '제59문', '하나님께서 이레 중 어느 날을 매주의 안식일로 정하셨는가?', '하나님께서 세상 창조로부터 그리스도의 부활까지는 이레 중 일곱째 날을, 그 후로는 첫째 날을 세상 끝날까지 매주의 안식일로 정하셨으니 곧 기독교의 안식일이다.', null, 59),
  ('catechism', 'ko', 60, '제60문', '안식일을 어떻게 거룩하게 지킬 것인가?', '안식일을 거룩하게 지키는 것은 그날 온종일 거룩히 쉬되 다른 날에 합당한 세상일과 오락을 그치고 부득이한 일과 자비를 베푸는 일 외에는 온 시간을 공적·사적 예배에 쓰는 것이다.', null, 60),
  ('catechism', 'ko', 61, '제61문', '제4계명이 무엇을 금하는가?', '제4계명은 요구하는 본분을 빠뜨리거나 소홀히 하는 것과 게으름이나 그 자체가 죄된 일로 그날을 더럽히는 것과 세상일이나 오락에 관한 불필요한 생각과 말과 행위로 더럽히는 것을 금한다.', null, 61),
  ('catechism', 'ko', 62, '제62문', '제4계명에 붙인 이유가 무엇인가?', '제4계명에 붙인 이유는 하나님께서 엿새 동안은 우리 일을 하도록 허락하시고 일곱째 날은 자기를 위하여 특별한 소유권을 주장하시며 친히 본을 보이시고 안식일에 복 주신 것이다.', null, 62),
  ('catechism', 'ko', 63, '제63문', '제5계명이 무엇인가?', '제5계명은 ''네 부모를 공경하라 그리하면 네 하나님 여호와가 네게 준 땅에서 네 생명이 길리라'' 하신 말씀이다.', null, 63),
  ('catechism', 'ko', 64, '제64문', '제5계명이 무엇을 요구하는가?', '제5계명은 각 사람의 지위와 관계에 따라 윗사람과 아랫사람과 동등한 자에게 마땅히 돌릴 존경과 본분을 지킬 것을 요구한다.', null, 64),
  ('catechism', 'ko', 65, '제65문', '제5계명이 무엇을 금하는가?', '제5계명은 각 사람의 지위와 관계에 합당한 존경과 본분을 소홀히 하거나 거스르는 모든 것을 금한다.', null, 65),
  ('catechism', 'ko', 66, '제66문', '제5계명에 붙인 이유가 무엇인가?', '제5계명에 붙인 이유는 이 계명을 지키는 모든 자에게 하나님의 영광과 그들 자신의 유익에 합당한 한 장수와 번영을 약속하신 것이다.', null, 66),
  ('catechism', 'ko', 67, '제67문', '제6계명이 무엇인가?', '제6계명은 ''살인하지 말라'' 하신 말씀이다.', null, 67),
  ('catechism', 'ko', 68, '제68문', '제6계명이 무엇을 요구하는가?', '제6계명은 우리 자신과 남의 생명을 보존하기 위하여 모든 합당한 노력을 다할 것을 요구한다.', null, 68),
  ('catechism', 'ko', 69, '제69문', '제6계명이 무엇을 금하는가?', '제6계명은 우리 자신이나 이웃의 생명을 부당하게 빼앗는 것과 그렇게 하려는 모든 것을 금한다.', null, 69),
  ('catechism', 'ko', 70, '제70문', '제7계명이 무엇인가?', '제7계명은 ''간음하지 말라'' 하신 말씀이다.', null, 70),
  ('catechism', 'ko', 71, '제71문', '제7계명이 무엇을 요구하는가?', '제7계명은 마음과 말과 행실에서 우리 자신과 이웃의 정결을 보존할 것을 요구한다.', null, 71),
  ('catechism', 'ko', 72, '제72문', '제7계명이 무엇을 금하는가?', '제7계명은 모든 부정한 생각과 말과 행실을 금한다.', null, 72),
  ('catechism', 'ko', 73, '제73문', '제8계명이 무엇인가?', '제8계명은 ''도둑질하지 말라'' 하신 말씀이다.', null, 73),
  ('catechism', 'ko', 74, '제74문', '제8계명이 무엇을 요구하는가?', '제8계명은 우리 자신과 남의 재산과 형편을 합당하게 얻고 늘리는 것을 요구한다.', null, 74),
  ('catechism', 'ko', 75, '제75문', '제8계명이 무엇을 금하는가?', '제8계명은 우리 자신이나 이웃의 재산과 형편을 부당하게 해롭게 하거나 해롭게 할 만한 모든 것을 금한다.', null, 75),
  ('catechism', 'ko', 76, '제76문', '제9계명이 무엇인가?', '제9계명은 ''네 이웃에 대하여 거짓 증거하지 말라'' 하신 말씀이다.', null, 76),
  ('catechism', 'ko', 77, '제77문', '제9계명이 무엇을 요구하는가?', '제9계명은 사람과 사람 사이에 진실을 지키고 보존하며 우리 자신과 이웃의 좋은 이름을 지키고 높일 것을 요구한다.', null, 77),
  ('catechism', 'ko', 78, '제78문', '제9계명이 무엇을 금하는가?', '제9계명은 진실을 해치거나 우리 자신이나 이웃의 좋은 이름을 해치는 모든 것을 금한다.', null, 78),
  ('catechism', 'ko', 79, '제79문', '제10계명이 무엇인가?', '제10계명은 ''네 이웃의 집을 탐내지 말라 네 이웃의 아내나 그의 남종이나 그의 여종이나 그의 소나 그의 나귀나 무릇 네 이웃의 소유를 탐내지 말라'' 하신 말씀이다.', null, 79),
  ('catechism', 'ko', 80, '제80문', '제10계명이 무엇을 요구하는가?', '제10계명은 우리 자신의 형편에 온전히 만족하고 이웃과 그에게 속한 모든 것에 대하여 올바르고 너그러운 마음을 가질 것을 요구한다.', null, 80),
  ('catechism', 'ko', 81, '제81문', '제10계명이 무엇을 금하는가?', '제10계명은 우리 형편에 불만하는 것과 이웃의 좋은 것을 시기하고 슬퍼하는 것과 그에게 속한 것을 지나치게 바라는 모든 마음을 금한다.', null, 81),
  ('catechism', 'ko', 82, '제82문', '어떤 사람이 하나님의 계명을 온전히 지킬 수 있는가?', '타락한 후로는 이 세상에서 아무도 하나님의 계명을 온전히 지킬 수 없고 날마다 생각과 말과 행실로 그것을 어긴다.', null, 82),
  ('catechism', 'ko', 83, '제83문', '율법을 어기는 모든 죄가 다 같이 악한가?', '어떤 죄는 그 자체로나 여러 정황으로 다른 죄보다 하나님 앞에서 더 악하다.', null, 83),
  ('catechism', 'ko', 84, '제84문', '모든 죄가 마땅히 무슨 벌을 받아야 하는가?', '모든 죄는 이 세상과 오는 세상에서 하나님의 진노와 저주를 받아 마땅하다.', null, 84),
  ('catechism', 'ko', 85, '제85문', '죄로 말미암아 받을 하나님의 진노와 저주를 피하려면 하나님이 우리에게 무엇을 요구하시는가?', '죄로 말미암아 받을 하나님의 진노와 저주를 피하려면 하나님께서 예수 그리스도를 믿는 믿음과 생명에 이르는 회개와 그리스도께서 구속의 은덕을 우리에게 전달하시는 모든 외적 방편을 부지런히 사용할 것을 요구하신다.', null, 85),
  ('catechism', 'ko', 86, '제86문', '예수 그리스도를 믿는 믿음이 무엇인가?', '예수 그리스도를 믿는 믿음은 구원하는 은혜니 우리가 복음에 제시된 대로 구원을 위하여 오직 그리스도만 영접하고 의지하는 것이다.', null, 86),
  ('catechism', 'ko', 87, '제87문', '생명에 이르는 회개가 무엇인가?', '생명에 이르는 회개는 구원하는 은혜니 죄인이 자기 죄를 참으로 깨닫고 하나님의 자비를 깨달아 그 죄를 슬퍼하고 미워하여 떠나 하나님께로 돌아와 새로 순종하기를 온전히 결심하고 힘쓰는 것이다.', null, 87),
  ('catechism', 'ko', 88, '제88문', '그리스도께서 구속의 은덕을 우리에게 전달하시는 외적 방편이 무엇인가?', '그리스도께서 구속의 은덕을 전달하시는 외적이고 통상적인 방편은 그의 규례들이니 특별히 말씀과 성례와 기도이며 이것들이 택한 자의 구원을 위하여 효력 있게 된다.', null, 88),
  ('catechism', 'ko', 89, '제89문', '말씀이 어떻게 구원에 효력 있게 되는가?', '하나님의 성령께서 말씀 읽는 것과 특별히 말씀 전하는 것을 죄인에게 죄를 깨닫게 하고 회개시키며 신자를 믿음으로 거룩함과 위로 안에 세워 구원에 이르게 하는 효력 있는 방편이 되게 하신다.', null, 89),
  ('catechism', 'ko', 90, '제90문', '말씀이 구원에 효력 있게 되려면 어떻게 읽고 들을 것인가?', '말씀이 구원에 효력 있게 되려면 부지런함과 준비와 기도로 말씀을 대하고 믿음과 사랑으로 받아 마음에 두고 생활에 실천해야 한다.', null, 90),
  ('catechism', 'ko', 91, '제91문', '성례가 어떻게 구원에 효력 있는 방편이 되는가?', '성례가 효력 있는 방편이 되는 것은 성례 자체나 베푸는 자의 덕이 아니라 오직 그리스도의 복 주심과 믿음으로 받는 자 안에서 역사하시는 성령으로 되는 것이다.', null, 91),
  ('catechism', 'ko', 92, '제92문', '성례가 무엇인가?', '성례는 그리스도께서 세우신 거룩한 규례니 눈에 보이는 표로 그리스도와 새 언약의 은덕을 나타내고 인치고 신자에게 적용하는 것이다.', null, 92),
  ('catechism', 'ko', 93, '제93문', '신약의 성례가 무엇인가?', '신약의 성례는 세례와 성찬이다.', null, 93),
  ('catechism', 'ko', 94, '제94문', '세례가 무엇인가?', '세례는 성부와 성자와 성령의 이름으로 물로 씻음으로 우리가 그리스도께 접붙임을 받는 것과 은혜 언약의 은덕에 참여하는 것과 주의 것이 되기로 약속함을 나타내고 인치는 성례이다.', null, 94),
  ('catechism', 'ko', 95, '제95문', '누구에게 세례를 베풀 것인가?', '유형교회 밖에 있는 자에게는 그리스도를 믿는 믿음과 그에게 순종함을 고백하기 전에는 세례를 베풀지 아니하나 유형교회 교인의 어린 자녀에게는 세례를 베푼다.', null, 95),
  ('catechism', 'ko', 96, '제96문', '성찬이 무엇인가?', '성찬은 그리스도께서 정하신 대로 떡과 포도주를 주고받음으로 그의 죽으심을 나타내는 성례니 합당하게 받는 자가 육신으로가 아니라 믿음으로 그의 몸과 피에 참여하여 모든 은덕을 받고 은혜 안에서 자라게 하는 것이다.', null, 96),
  ('catechism', 'ko', 97, '제97문', '성찬을 합당하게 받으려면 무엇이 요구되는가?', '성찬을 합당하게 받으려면 주의 몸을 분별하는 지식과 그를 의지하는 믿음과 회개와 사랑과 새로 순종함을 자기가 가졌는지 살펴야 하니 합당하지 않게 오면 자기에게 심판을 먹고 마시는 것이다.', null, 97),
  ('catechism', 'ko', 98, '제98문', '기도가 무엇인가?', '기도는 하나님의 뜻에 합당한 것을 위하여 그리스도의 이름으로 우리의 소원을 하나님께 아뢰는 것이니 우리의 죄를 자백하고 그의 자비하심을 감사함으로 하는 것이다.', null, 98),
  ('catechism', 'ko', 99, '제99문', '하나님께서 우리의 기도를 인도하시려고 무슨 법칙을 주셨는가?', '하나님의 말씀 전체가 기도를 인도하는 데 유익하나 특별한 법칙은 그리스도께서 제자들에게 가르치신 기도니 곧 주기도문이다.', null, 99),
  ('catechism', 'ko', 100, '제100문', '주기도문의 서언이 우리에게 무엇을 가르치는가?', '''하늘에 계신 우리 아버지여''라는 서언은 우리가 하나님께 나아가기를 아버지께 나아가는 자녀와 같이 거룩한 경외와 확신으로 할 것과 다른 사람과 함께 그들을 위하여 기도할 것을 가르친다.', null, 100),
  ('catechism', 'ko', 101, '제101문', '첫째 간구에서 우리가 무엇을 구하는가?', '''이름이 거룩히 여김을 받으시오며''라는 첫째 간구에서 우리는 하나님께서 우리와 모든 사람으로 그를 영화롭게 하게 하시고 모든 일을 그의 영광이 되도록 처리해 주시기를 구한다.', null, 101),
  ('catechism', 'ko', 102, '제102문', '둘째 간구에서 우리가 무엇을 구하는가?', '''나라가 임하시오며''라는 둘째 간구에서 우리는 사탄의 나라가 망하고 은혜의 나라가 흥왕하여 우리와 다른 사람이 거기 들어가 지켜지며 영광의 나라가 속히 임하기를 구한다.', null, 102),
  ('catechism', 'ko', 103, '제103문', '셋째 간구에서 우리가 무엇을 구하는가?', '''뜻이 하늘에서 이루어진 것 같이 땅에서도 이루어지이다''라는 셋째 간구에서 우리는 하나님께서 은혜로 우리를 하늘의 천사들과 같이 모든 일에 그의 뜻을 알고 순종하고 복종하게 하시기를 구한다.', null, 103),
  ('catechism', 'ko', 104, '제104문', '넷째 간구에서 우리가 무엇을 구하는가?', '''오늘 우리에게 일용할 양식을 주시옵고''라는 넷째 간구에서 우리는 하나님의 값없이 주시는 선물로 이 세상의 좋은 것을 넉넉히 받아 누리며 그와 함께 그의 복을 받기를 구한다.', null, 104),
  ('catechism', 'ko', 105, '제105문', '다섯째 간구에서 우리가 무엇을 구하는가?', '''우리가 우리에게 죄 지은 자를 사하여 준 것 같이 우리 죄를 사하여 주시옵고''라는 다섯째 간구에서 우리는 하나님께서 그리스도로 말미암아 우리의 모든 죄를 값없이 사하여 주시기를 구하니 우리가 마음으로 다른 사람을 용서하게 하시는 그 은혜 때문에 더욱 담대히 구한다.', null, 105),
  ('catechism', 'ko', 106, '제106문', '여섯째 간구에서 우리가 무엇을 구하는가?', '''우리를 시험에 들게 하지 마시옵고 다만 악에서 구하시옵소서''라는 여섯째 간구에서 우리는 하나님께서 우리를 죄에 빠지도록 시험하지 않으시며 시험받을 때에 붙드시고 건져 주시기를 구한다.', null, 106),
  ('catechism', 'ko', 107, '제107문', '주기도문의 결언이 우리에게 무엇을 가르치는가?', '''나라와 권세와 영광이 아버지께 영원히 있사옵나이다 아멘''이라는 결언은 우리가 기도할 용기를 오직 하나님께로부터 얻고 찬송을 그에게만 돌릴 것과 구한 것을 들으신다는 소원과 확신으로 아멘이라 할 것을 가르친다.', null, 107),
-- ── 영문 (Westminster Shorter Catechism, 1647 · public domain) ──
  ('catechism', 'en', 1, 'Q1', 'What is the chief end of man?', 'Man''s chief end is to glorify God, and to enjoy him forever.', null, 1),
  ('catechism', 'en', 2, 'Q2', 'What rule hath God given to direct us how we may glorify and enjoy him?', 'The Word of God, which is contained in the Scriptures of the Old and New Testaments, is the only rule to direct us how we may glorify and enjoy him.', null, 2),
  ('catechism', 'en', 3, 'Q3', 'What do the Scriptures principally teach?', 'The Scriptures principally teach what man is to believe concerning God, and what duty God requires of man.', null, 3),
  ('catechism', 'en', 4, 'Q4', 'What is God?', 'God is a Spirit, infinite, eternal, and unchangeable, in his being, wisdom, power, holiness, justice, goodness, and truth.', null, 4),
  ('catechism', 'en', 5, 'Q5', 'Are there more Gods than one?', 'There is but one only, the living and true God.', null, 5),
  ('catechism', 'en', 6, 'Q6', 'How many persons are there in the Godhead?', 'There are three persons in the Godhead: the Father, the Son, and the Holy Ghost; and these three are one God, the same in substance, equal in power and glory.', null, 6),
  ('catechism', 'en', 7, 'Q7', 'What are the decrees of God?', 'The decrees of God are his eternal purpose, according to the counsel of his will, whereby, for his own glory, he hath foreordained whatsoever comes to pass.', null, 7),
  ('catechism', 'en', 8, 'Q8', 'How doth God execute his decrees?', 'God executeth his decrees in the works of creation and providence.', null, 8),
  ('catechism', 'en', 9, 'Q9', 'What is the work of creation?', 'The work of creation is God''s making all things of nothing, by the word of his power, in the space of six days, and all very good.', null, 9),
  ('catechism', 'en', 10, 'Q10', 'How did God create man?', 'God created man male and female, after his own image, in knowledge, righteousness, and holiness, with dominion over the creatures.', null, 10),
  ('catechism', 'en', 11, 'Q11', 'What are God''s works of providence?', 'God''s works of providence are his most holy, wise, and powerful preserving and governing all his creatures, and all their actions.', null, 11),
  ('catechism', 'en', 12, 'Q12', 'What special act of providence did God exercise toward man in the estate wherein he was created?', 'When God had created man, he entered into a covenant of life with him, upon condition of perfect obedience; forbidding him to eat of the tree of the knowledge of good and evil, upon the pain of death.', null, 12),
  ('catechism', 'en', 13, 'Q13', 'Did our first parents continue in the estate wherein they were created?', 'Our first parents, being left to the freedom of their own will, fell from the estate wherein they were created, by sinning against God.', null, 13),
  ('catechism', 'en', 14, 'Q14', 'What is sin?', 'Sin is any want of conformity unto, or transgression of, the law of God.', null, 14),
  ('catechism', 'en', 15, 'Q15', 'What was the sin whereby our first parents fell from the estate wherein they were created?', 'The sin whereby our first parents fell from the estate wherein they were created was their eating the forbidden fruit.', null, 15),
  ('catechism', 'en', 16, 'Q16', 'Did all mankind fall in Adam''s first transgression?', 'The covenant being made with Adam, not only for himself, but for his posterity; all mankind, descending from him by ordinary generation, sinned in him, and fell with him, in his first transgression.', null, 16),
  ('catechism', 'en', 17, 'Q17', 'Into what estate did the fall bring mankind?', 'The fall brought mankind into an estate of sin and misery.', null, 17),
  ('catechism', 'en', 18, 'Q18', 'Wherein consists the sinfulness of that estate whereinto man fell?', 'The sinfulness of that estate whereinto man fell, consists in the guilt of Adam''s first sin, the want of original righteousness, and the corruption of his whole nature, which is commonly called original sin; together with all actual transgressions which proceed from it.', null, 18),
  ('catechism', 'en', 19, 'Q19', 'What is the misery of that estate whereinto man fell?', 'All mankind by their fall lost communion with God, are under his wrath and curse, and so made liable to all miseries in this life, to death itself, and to the pains of hell forever.', null, 19),
  ('catechism', 'en', 20, 'Q20', 'Did God leave all mankind to perish in the estate of sin and misery?', 'God having, out of his mere good pleasure, from all eternity, elected some to everlasting life, did enter into a covenant of grace, to deliver them out of the estate of sin and misery, and to bring them into an estate of salvation by a Redeemer.', null, 20),
  ('catechism', 'en', 21, 'Q21', 'Who is the Redeemer of God''s elect?', 'The only Redeemer of God''s elect is the Lord Jesus Christ, who, being the eternal Son of God, became man, and so was, and continueth to be, God and man in two distinct natures, and one person, forever.', null, 21),
  ('catechism', 'en', 22, 'Q22', 'How did Christ, being the Son of God, become man?', 'Christ, the Son of God, became man, by taking to himself a true body and a reasonable soul, being conceived by the power of the Holy Ghost in the womb of the virgin Mary, and born of her, yet without sin.', null, 22),
  ('catechism', 'en', 23, 'Q23', 'What offices doth Christ execute as our Redeemer?', 'Christ, as our Redeemer, executeth the offices of a prophet, of a priest, and of a king, both in his estate of humiliation and exaltation.', null, 23),
  ('catechism', 'en', 24, 'Q24', 'How doth Christ execute the office of a prophet?', 'Christ executeth the office of a prophet, in revealing to us, by his Word and Spirit, the will of God for our salvation.', null, 24),
  ('catechism', 'en', 25, 'Q25', 'How doth Christ execute the office of a priest?', 'Christ executeth the office of a priest, in his once offering up of himself a sacrifice to satisfy divine justice, and reconcile us to God, and in making continual intercession for us.', null, 25),
  ('catechism', 'en', 26, 'Q26', 'How doth Christ execute the office of a king?', 'Christ executeth the office of a king, in subduing us to himself, in ruling and defending us, and in restraining and conquering all his and our enemies.', null, 26),
  ('catechism', 'en', 27, 'Q27', 'Wherein did Christ''s humiliation consist?', 'Christ''s humiliation consisted in his being born, and that in a low condition, made under the law, undergoing the miseries of this life, the wrath of God, and the cursed death of the cross; in being buried, and continuing under the power of death for a time.', null, 27),
  ('catechism', 'en', 28, 'Q28', 'Wherein consisteth Christ''s exaltation?', 'Christ''s exaltation consisteth in his rising again from the dead on the third day, in ascending up into heaven, in sitting at the right hand of God the Father, and in coming to judge the world at the last day.', null, 28),
  ('catechism', 'en', 29, 'Q29', 'How are we made partakers of the redemption purchased by Christ?', 'We are made partakers of the redemption purchased by Christ, by the effectual application of it to us by his Holy Spirit.', null, 29),
  ('catechism', 'en', 30, 'Q30', 'How doth the Spirit apply to us the redemption purchased by Christ?', 'The Spirit applieth to us the redemption purchased by Christ, by working faith in us, and thereby uniting us to Christ in our effectual calling.', null, 30),
  ('catechism', 'en', 31, 'Q31', 'What is effectual calling?', 'Effectual calling is the work of God''s Spirit, whereby, convincing us of our sin and misery, enlightening our minds in the knowledge of Christ, and renewing our wills, he doth persuade and enable us to embrace Jesus Christ, freely offered to us in the gospel.', null, 31),
  ('catechism', 'en', 32, 'Q32', 'What benefits do they that are effectually called partake of in this life?', 'They that are effectually called do in this life partake of justification, adoption, and sanctification, and the several benefits which in this life do either accompany or flow from them.', null, 32),
  ('catechism', 'en', 33, 'Q33', 'What is justification?', 'Justification is an act of God''s free grace, wherein he pardoneth all our sins, and accepteth us as righteous in his sight, only for the righteousness of Christ imputed to us, and received by faith alone.', null, 33),
  ('catechism', 'en', 34, 'Q34', 'What is adoption?', 'Adoption is an act of God''s free grace, whereby we are received into the number, and have a right to all the privileges of, the sons of God.', null, 34),
  ('catechism', 'en', 35, 'Q35', 'What is sanctification?', 'Sanctification is the work of God''s free grace, whereby we are renewed in the whole man after the image of God, and are enabled more and more to die unto sin, and live unto righteousness.', null, 35),
  ('catechism', 'en', 36, 'Q36', 'What are the benefits which in this life do accompany or flow from justification, adoption, and sanctification?', 'The benefits which in this life do accompany or flow from justification, adoption, and sanctification, are, assurance of God''s love, peace of conscience, joy in the Holy Ghost, increase of grace, and perseverance therein to the end.', null, 36),
  ('catechism', 'en', 37, 'Q37', 'What benefits do believers receive from Christ at death?', 'The souls of believers are at their death made perfect in holiness, and do immediately pass into glory; and their bodies, being still united to Christ, do rest in their graves till the resurrection.', null, 37),
  ('catechism', 'en', 38, 'Q38', 'What benefits do believers receive from Christ at the resurrection?', 'At the resurrection, believers being raised up in glory, shall be openly acknowledged and acquitted in the day of judgment, and made perfectly blessed in the full enjoying of God to all eternity.', null, 38),
  ('catechism', 'en', 39, 'Q39', 'What is the duty which God requireth of man?', 'The duty which God requireth of man, is obedience to his revealed will.', null, 39),
  ('catechism', 'en', 40, 'Q40', 'What did God at first reveal to man for the rule of his obedience?', 'The rule which God at first revealed to man for his obedience, was the moral law.', null, 40),
  ('catechism', 'en', 41, 'Q41', 'Where is the moral law summarily comprehended?', 'The moral law is summarily comprehended in the ten commandments.', null, 41),
  ('catechism', 'en', 42, 'Q42', 'What is the sum of the ten commandments?', 'The sum of the ten commandments is, to love the Lord our God with all our heart, with all our soul, with all our strength, and with all our mind; and our neighbour as ourselves.', null, 42),
  ('catechism', 'en', 43, 'Q43', 'What is the preface to the ten commandments?', 'The preface to the ten commandments is in these words, I am the Lord thy God, which have brought thee out of the land of Egypt, out of the house of bondage.', null, 43),
  ('catechism', 'en', 44, 'Q44', 'What doth the preface to the ten commandments teach us?', 'The preface to the ten commandments teacheth us, That because God is the Lord, and our God, and Redeemer, therefore we are bound to keep all his commandments.', null, 44),
  ('catechism', 'en', 45, 'Q45', 'Which is the first commandment?', 'The first commandment is, Thou shalt have no other gods before me.', null, 45),
  ('catechism', 'en', 46, 'Q46', 'What is required in the first commandment?', 'The first commandment requireth us to know and acknowledge God to be the only true God, and our God; and to worship and glorify him accordingly.', null, 46),
  ('catechism', 'en', 47, 'Q47', 'What is forbidden in the first commandment?', 'The first commandment forbiddeth the denying, or not worshipping and glorifying the true God as God, and our God; and the giving of that worship and glory to any other, which is due to him alone.', null, 47),
  ('catechism', 'en', 48, 'Q48', 'What are we specially taught by these words, “before me,” in the first commandment?', 'These words, “before me,” in the first commandment, teach us, That God, who seeth all things, taketh notice of, and is much displeased with, the sin of having any other God.', null, 48),
  ('catechism', 'en', 49, 'Q49', 'Which is the second commandment?', 'The second commandment is, Thou shalt not make unto thee any graven image, or any likeness of any thing that is in heaven above, or that is in the earth beneath, or that is in the water under the earth: thou shalt not bow down thyself to them, nor serve them: for I the Lord thy God am a jealous God, visiting the iniquity of the fathers upon the children, unto the third and fourth generation of them that hate me; and shewing mercy unto thousands of them that love me, and keep my commandments.', null, 49),
  ('catechism', 'en', 50, 'Q50', 'What is required in the second commandment?', 'The second commandment requireth the receiving, observing, and keeping pure and entire, all such religious worship and ordinances as God hath appointed in his Word.', null, 50),
  ('catechism', 'en', 51, 'Q51', 'What is forbidden in the second commandment?', 'The second commandment forbiddeth the worshipping of God by images, or any other way not appointed in his Word.', null, 51),
  ('catechism', 'en', 52, 'Q52', 'What are the reasons annexed to the second commandment?', 'The reasons annexed to the second commandment are, God''s sovereignty over us, his propriety in us, and the zeal he hath to his own worship.', null, 52),
  ('catechism', 'en', 53, 'Q53', 'Which is the third commandment?', 'The third commandment is, Thou shalt not take the name of the Lord thy God in vain; for the Lord will not hold him guiltless that taketh his name in vain.', null, 53),
  ('catechism', 'en', 54, 'Q54', 'What is required in the third commandment?', 'The third commandment requireth the holy and reverent use of God''s names, titles, attributes, ordinances, Word, and works.', null, 54),
  ('catechism', 'en', 55, 'Q55', 'What is forbidden in the third commandment?', 'The third commandment forbiddeth all profaning or abusing of any thing whereby God maketh himself known.', null, 55),
  ('catechism', 'en', 56, 'Q56', 'What is the reason annexed to the third commandment?', 'The reason annexed to the third commandment is, That however the breakers of this commandment may escape punishment from men, yet the Lord our God will not suffer them to escape his righteous judgment.', null, 56),
  ('catechism', 'en', 57, 'Q57', 'Which is the fourth commandment?', 'The fourth commandment is, Remember the sabbath day, to keep it holy. Six days shalt thou labour, and do all thy work: but the seventh day is the sabbath of the Lord thy God: in it thou shalt not do any work, thou, nor thy son, nor thy daughter, thy manservant, nor thy maidservant, nor thy cattle, nor thy stranger that is within thy gates: for in six days the Lord made heaven and earth, the sea, and all that in them is, and rested the seventh day: wherefore the Lord blessed the sabbath day, and hallowed it.', null, 57),
  ('catechism', 'en', 58, 'Q58', 'What is required in the fourth commandment?', 'The fourth commandment requireth the keeping holy to God such set times as he hath appointed in his Word; expressly one whole day in seven, to be a holy sabbath to himself.', null, 58),
  ('catechism', 'en', 59, 'Q59', 'Which day of the seven hath God appointed to be the weekly sabbath?', 'From the beginning of the world to the resurrection of Christ, God appointed the seventh day of the week to be the weekly sabbath; and the first day of the week ever since, to continue to the end of the world, which is the Christian sabbath.', null, 59),
  ('catechism', 'en', 60, 'Q60', 'How is the sabbath to be sanctified?', 'The sabbath is to be sanctified by a holy resting all that day, even from such worldly employments and recreations as are lawful on other days; and spending the whole time in the public and private exercises of God''s worship, except so much as is to be taken up in the works of necessity and mercy.', null, 60),
  ('catechism', 'en', 61, 'Q61', 'What is forbidden in the fourth commandment?', 'The fourth commandment forbiddeth the omission or careless performance of the duties required, and the profaning the day by idleness, or doing that which is in itself sinful, or by unnecessary thoughts, words, or works, about our worldly employments or recreations.', null, 61),
  ('catechism', 'en', 62, 'Q62', 'What are the reasons annexed to the fourth commandment?', 'The reasons annexed to the fourth commandment are, God''s allowing us six days of the week for our own employments, his challenging a special propriety in the seventh, his own example, and his blessing the sabbath day.', null, 62),
  ('catechism', 'en', 63, 'Q63', 'Which is the fifth commandment?', 'The fifth commandment is, Honour thy father and thy mother: that thy days may be long upon the land which the Lord thy God giveth thee.', null, 63),
  ('catechism', 'en', 64, 'Q64', 'What is required in the fifth commandment?', 'The fifth commandment requireth the preserving the honour, and performing the duties, belonging to every one in their several places and relations, as superiors, inferiors, or equals.', null, 64),
  ('catechism', 'en', 65, 'Q65', 'What is forbidden in the fifth commandment?', 'The fifth commandment forbiddeth the neglecting of, or doing any thing against, the honour and duty which belongeth to every one in their several places and relations.', null, 65),
  ('catechism', 'en', 66, 'Q66', 'What is the reason annexed to the fifth commandment?', 'The reason annexed to the fifth commandment is, a promise of long life and prosperity (as far as it shall serve for God''s glory and their own good) to all such as keep this commandment.', null, 66),
  ('catechism', 'en', 67, 'Q67', 'Which is the sixth commandment?', 'The sixth commandment is, Thou shalt not kill.', null, 67),
  ('catechism', 'en', 68, 'Q68', 'What is required in the sixth commandment?', 'The sixth commandment requireth all lawful endeavours to preserve our own life, and the life of others.', null, 68),
  ('catechism', 'en', 69, 'Q69', 'What is forbidden in the sixth commandment?', 'The sixth commandment forbiddeth the taking away of our own life, or the life of our neighbour unjustly, or whatsoever tendeth thereunto.', null, 69),
  ('catechism', 'en', 70, 'Q70', 'Which is the seventh commandment?', 'The seventh commandment is, Thou shalt not commit adultery.', null, 70),
  ('catechism', 'en', 71, 'Q71', 'What is required in the seventh commandment?', 'The seventh commandment requireth the preservation of our own and our neighbour''s chastity, in heart, speech, and behaviour.', null, 71),
  ('catechism', 'en', 72, 'Q72', 'What is forbidden in the seventh commandment?', 'The seventh commandment forbiddeth all unchaste thoughts, words, and actions.', null, 72),
  ('catechism', 'en', 73, 'Q73', 'Which is the eighth commandment?', 'The eighth commandment is, Thou shalt not steal.', null, 73),
  ('catechism', 'en', 74, 'Q74', 'What is required in the eighth commandment?', 'The eighth commandment requireth the lawful procuring and furthering the wealth and outward estate of ourselves and others.', null, 74),
  ('catechism', 'en', 75, 'Q75', 'What is forbidden in the eighth commandment?', 'The eighth commandment forbiddeth whatsoever doth, or may, unjustly hinder our own, or our neighbour''s, wealth or outward estate.', null, 75),
  ('catechism', 'en', 76, 'Q76', 'Which is the ninth commandment?', 'The ninth commandment is, Thou shalt not bear false witness against thy neighbour.', null, 76),
  ('catechism', 'en', 77, 'Q77', 'What is required in the ninth commandment?', 'The ninth commandment requireth the maintaining and promoting of truth between man and man, and of our own and our neighbour''s good name, especially in witness-bearing.', null, 77),
  ('catechism', 'en', 78, 'Q78', 'What is forbidden in the ninth commandment?', 'The ninth commandment forbiddeth whatsoever is prejudicial to truth, or injurious to our own, or our neighbour''s, good name.', null, 78),
  ('catechism', 'en', 79, 'Q79', 'Which is the tenth commandment?', 'The tenth commandment is, Thou shalt not covet thy neighbour''s house, thou shalt not covet thy neighbour''s wife, nor his manservant, nor his maidservant, nor his ox, nor his ass, nor any thing that is thy neighbour''s.', null, 79),
  ('catechism', 'en', 80, 'Q80', 'What is required in the tenth commandment?', 'The tenth commandment requireth full contentment with our own condition, with a right and charitable frame of spirit toward our neighbour, and all that is his.', null, 80),
  ('catechism', 'en', 81, 'Q81', 'What is forbidden in the tenth commandment?', 'The tenth commandment forbiddeth all discontentment with our own estate, envying or grieving at the good of our neighbour, and all inordinate motions and affections to any thing that is his.', null, 81),
  ('catechism', 'en', 82, 'Q82', 'Is any man able perfectly to keep the commandments of God?', 'No mere man since the fall is able in this life perfectly to keep the commandments of God, but doth daily break them, in thought, word, and deed.', null, 82),
  ('catechism', 'en', 83, 'Q83', 'Are all transgressions of the law equally heinous?', 'Some sins in themselves, and by reason of several aggravations, are more heinous in the sight of God than others.', null, 83),
  ('catechism', 'en', 84, 'Q84', 'What doth every sin deserve?', 'Every sin deserveth God''s wrath and curse, both in this life, and that which is to come.', null, 84),
  ('catechism', 'en', 85, 'Q85', 'What doth God require of us, that we may escape his wrath and curse due to us for sin?', 'To escape the wrath and curse of God due to us for sin, God requireth of us faith in Jesus Christ, repentance unto life, with the diligent use of all the outward means whereby Christ communicateth to us the benefits of redemption.', null, 85),
  ('catechism', 'en', 86, 'Q86', 'What is faith in Jesus Christ?', 'Faith in Jesus Christ is a saving grace, whereby we receive and rest upon him alone for salvation, as he is offered to us in the gospel.', null, 86),
  ('catechism', 'en', 87, 'Q87', 'What is repentance unto life?', 'Repentance unto life is a saving grace, whereby a sinner, out of a true sense of his sin, and apprehension of the mercy of God in Christ, doth, with grief and hatred of his sin, turn from it unto God, with full purpose of, and endeavour after, new obedience.', null, 87),
  ('catechism', 'en', 88, 'Q88', 'What are the outward and ordinary means whereby Christ communicateth to us the benefits of redemption?', 'The outward and ordinary means whereby Christ communicateth to us the benefits of redemption, are his ordinances, especially the Word, sacraments, and prayer; all which are made effectual to the elect for salvation.', null, 88),
  ('catechism', 'en', 89, 'Q89', 'How is the Word made effectual to salvation?', 'The Spirit of God maketh the reading, but especially the preaching, of the Word, an effectual means of convincing and converting sinners, and of building them up in holiness and comfort, through faith, unto salvation.', null, 89),
  ('catechism', 'en', 90, 'Q90', 'How is the Word to be read and heard, that it may become effectual to salvation?', 'That the Word may become effectual to salvation, we must attend thereunto with diligence, preparation, and prayer; receive it with faith and love, lay it up in our hearts, and practise it in our lives.', null, 90),
  ('catechism', 'en', 91, 'Q91', 'How do the sacraments become effectual means of salvation?', 'The sacraments become effectual means of salvation, not from any virtue in them, or in him that doth administer them; but only by the blessing of Christ, and the working of his Spirit in them that by faith receive them.', null, 91),
  ('catechism', 'en', 92, 'Q92', 'What is a sacrament?', 'A sacrament is an holy ordinance instituted by Christ; wherein, by sensible signs, Christ, and the benefits of the new covenant, are represented, sealed, and applied to believers.', null, 92),
  ('catechism', 'en', 93, 'Q93', 'Which are the sacraments of the New Testament?', 'The sacraments of the New Testament are baptism and the Lord''s supper.', null, 93),
  ('catechism', 'en', 94, 'Q94', 'What is baptism?', 'Baptism is a sacrament, wherein the washing with water in the name of the Father, and of the Son, and of the Holy Ghost, doth signify and seal our ingrafting into Christ, and partaking of the benefits of the covenant of grace, and our engagement to be the Lord''s.', null, 94),
  ('catechism', 'en', 95, 'Q95', 'To whom is baptism to be administered?', 'Baptism is not to be administered to any that are out of the visible church, till they profess their faith in Christ, and obedience to him; but the infants of such as are members of the visible church are to be baptized.', null, 95),
  ('catechism', 'en', 96, 'Q96', 'What is the Lord''s supper?', 'The Lord''s supper is a sacrament, wherein, by giving and receiving bread and wine, according to Christ''s appointment, his death is shewed forth; and the worthy receivers are, not after a corporal and carnal manner, but by faith, made partakers of his body and blood, with all his benefits, to their spiritual nourishment, and growth in grace.', null, 96),
  ('catechism', 'en', 97, 'Q97', 'What is required to the worthy receiving of the Lord''s supper?', 'It is required of them that would worthily partake of the Lord''s supper, that they examine themselves of their knowledge to discern the Lord''s body, of their faith to feed upon him, of their repentance, love, and new obedience; lest, coming unworthily, they eat and drink judgment to themselves.', null, 97),
  ('catechism', 'en', 98, 'Q98', 'What is prayer?', 'Prayer is an offering up of our desires unto God, for things agreeable to his will, in the name of Christ, with confession of our sins, and thankful acknowledgment of his mercies.', null, 98),
  ('catechism', 'en', 99, 'Q99', 'What rule hath God given for our direction in prayer?', 'The whole Word of God is of use to direct us in prayer; but the special rule of direction is that form of prayer which Christ taught his disciples, commonly called the Lord''s prayer.', null, 99),
  ('catechism', 'en', 100, 'Q100', 'What doth the preface of the Lord''s prayer teach us?', 'The preface of the Lord''s prayer, which is, Our Father which art in heaven, teacheth us to draw near to God with all holy reverence and confidence, as children to a father, able and ready to help us; and that we should pray with and for others.', null, 100),
  ('catechism', 'en', 101, 'Q101', 'What do we pray for in the first petition?', 'In the first petition, which is, Hallowed be thy name, we pray, That God would enable us, and others, to glorify him in all that whereby he maketh himself known; and that he would dispose all things to his own glory.', null, 101),
  ('catechism', 'en', 102, 'Q102', 'What do we pray for in the second petition?', 'In the second petition, which is, Thy kingdom come, we pray, That Satan''s kingdom may be destroyed; and that the kingdom of grace may be advanced, ourselves and others brought into it, and kept in it; and that the kingdom of glory may be hastened.', null, 102),
  ('catechism', 'en', 103, 'Q103', 'What do we pray for in the third petition?', 'In the third petition, which is, Thy will be done in earth, as it is in heaven, we pray, That God, by his grace, would make us able and willing to know, obey, and submit to his will in all things, as the angels do in heaven.', null, 103),
  ('catechism', 'en', 104, 'Q104', 'What do we pray for in the fourth petition?', 'In the fourth petition, which is, Give us this day our daily bread, we pray, That of God''s free gift we may receive a competent portion of the good things of this life, and enjoy his blessing with them.', null, 104),
  ('catechism', 'en', 105, 'Q105', 'What do we pray for in the fifth petition?', 'In the fifth petition, which is, And forgive us our debts, as we forgive our debtors, we pray, That God, for Christ''s sake, would freely pardon all our sins; which we are the rather encouraged to ask, because by his grace we are enabled from the heart to forgive others.', null, 105),
  ('catechism', 'en', 106, 'Q106', 'What do we pray for in the sixth petition?', 'In the sixth petition, which is, And lead us not into temptation, but deliver us from evil, we pray, That God would either keep us from being tempted to sin, or support and deliver us when we are tempted.', null, 106),
  ('catechism', 'en', 107, 'Q107', 'What doth the conclusion of the Lord''s prayer teach us?', 'The conclusion of the Lord''s prayer, which is, For thine is the kingdom, and the power, and the glory, for ever, Amen, teacheth us to take our encouragement in prayer from God only, and in our prayers to praise him, ascribing kingdom, power, and glory to him; and, in testimony of our desire, and assurance to be heard, we say, Amen.', null, 107);

notify pgrst, 'reload schema';

select lang as "말", count(*) as "문항" from public.memory_items
 where kind='catechism' group by 1 order by 1;


-- ══════ db/트리플스쿨_AI분석_댓글_DB설치.sql ══════
-- =====================================================================
--  Triple School 최종 독후감 : ① AI 분석 결과 저장  ② 교직원 댓글(피드백)
--  · AI 분석은 한 번 돌리면 저장되어 다시 들어와도 그대로 보입니다.
--  · 댓글은 간사 이상(학생 제외)만 작성, 학생은 자기 것만 읽습니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- 교직원(간사 이상) 판별 헬퍼 — 이미 있으면 갱신
create or replace function public.is_school_staff()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role in ('super_admin','vice_admin','community_admin','admin_officer','teacher','staff')
        or me.role in ('총관리자','부총관리자','관리자','행정담당자','교사','간사')
      )
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

-- ─────────────────────────────────────────────────────────────
-- ① AI 분석 결과 (책 × 학생 당 1개, 다시 분석하면 덮어씀)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reading_ai_reviews (
  id               uuid primary key default gen_random_uuid(),
  book_id          uuid not null references public.reading_books(id) on delete cascade,
  student_id       uuid not null references public.members(id) on delete cascade,
  community_id     uuid,
  result           jsonb not null,            -- {likelihood,score,summary,signals,excerpts,questions}
  word_count       int,                       -- 분석 당시 독후감 단어 수(재제출 감지용)
  analyzed_by      uuid,
  analyzed_by_name text,
  created_at       timestamptz not null default now()
);
create unique index if not exists uq_reading_ai_reviews on public.reading_ai_reviews (book_id, student_id);

alter table public.reading_ai_reviews enable row level security;
drop policy if exists rair_select on public.reading_ai_reviews;
drop policy if exists rair_insert on public.reading_ai_reviews;
drop policy if exists rair_update on public.reading_ai_reviews;
drop policy if exists rair_delete on public.reading_ai_reviews;

-- 조회: 교직원만 (AI 판정은 학생에게 노출하지 않음)
create policy rair_select on public.reading_ai_reviews for select to authenticated
  using (public.is_school_staff());
create policy rair_insert on public.reading_ai_reviews for insert to authenticated
  with check (public.is_school_staff());
create policy rair_update on public.reading_ai_reviews for update to authenticated
  using (public.is_school_staff()) with check (public.is_school_staff());
create policy rair_delete on public.reading_ai_reviews for delete to authenticated
  using (public.is_school_staff());

-- ─────────────────────────────────────────────────────────────
-- ② 최종 독후감 댓글 (간사 이상 작성 · 학생은 자기 것 열람)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reading_report_comments (
  id            uuid primary key default gen_random_uuid(),
  book_id       uuid not null references public.reading_books(id) on delete cascade,
  student_id    uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  author_id     uuid not null,
  author_name   text,
  content       text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz
);
create index if not exists idx_rrc_book_student
  on public.reading_report_comments (book_id, student_id, created_at);

alter table public.reading_report_comments enable row level security;
drop policy if exists rrc_select on public.reading_report_comments;
drop policy if exists rrc_insert on public.reading_report_comments;
drop policy if exists rrc_update on public.reading_report_comments;
drop policy if exists rrc_delete on public.reading_report_comments;

-- 조회: 교직원 + 해당 학생 본인(자기가 받은 피드백은 볼 수 있어야 함)
create policy rrc_select on public.reading_report_comments for select to authenticated
  using (public.is_school_staff() or student_id = auth.uid());
-- 작성: 간사 이상만, 작성자는 본인으로 고정
create policy rrc_insert on public.reading_report_comments for insert to authenticated
  with check (public.is_school_staff() and author_id = auth.uid());
-- 수정/삭제: 본인이 쓴 댓글만 (단, 관리자는 모두 가능)
create policy rrc_update on public.reading_report_comments for update to authenticated
  using (author_id = auth.uid() and public.is_school_staff())
  with check (author_id = auth.uid() and public.is_school_staff());
create policy rrc_delete on public.reading_report_comments for delete to authenticated
  using (
    (author_id = auth.uid() and public.is_school_staff())
    or exists (select 1 from public.members me where me.id = auth.uid()
               and me.community_role in ('super_admin','vice_admin','community_admin'))
  );

NOTIFY pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════════
--  🔒 9) 채팅방 권한 잠그기  (db/채팅방_권한_잠그기.sql)
--
--  학생이 단체방을 만들어 남을 초대할 수 있었습니다. 그뿐 아니라 남의
--  1:1 대화가 그대로 읽히고, 남의 방에 글을 쓰고, 선생님을 내쫓고,
--  방을 통째로 지울 수도 있었습니다 — 여덟 가지를 지역 데이터베이스에
--  똑같이 깔아서 확인했습니다.  자세한 내용: docs/채팅방_권한_점검.md
-- ════════════════════════════════════════════════════════════════════

-- ── 0. 기대는 도우미가 없으면 여기서 만든다 ───────────────────────
--  db/신고차단_DB설치.sql 을 먼저 돌리셨으면 이미 있습니다. 같은 내용입니다.
create or replace function public.staff_of(cid uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_role in ('super_admin','vice_admin')
          or ( me.community_id = cid
               and me.community_role in ('community_admin','admin_officer','teacher','staff') ) )
  );
$$;
grant execute on function public.staff_of(uuid) to authenticated;

create or replace function public.can_moderate_channel(ch uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.channels c
                  where c.id = ch and public.staff_of(c.community_id));
$$;
grant execute on function public.can_moderate_channel(uuid) to authenticated;

--  mine_comm 도 없을 수 있습니다 (db/전체잠그기_RLS.sql 을 안 돌리신 경우).
create or replace function public.mine_comm(cid uuid)
returns boolean language sql security definer stable parallel safe
set search_path = public as $$
  select exists (select 1 from public.members me
                  where me.id = auth.uid()
                    and coalesce(me.status, 'active') <> 'removed'
                    and (me.community_id = cid
                         or me.community_role in ('super_admin','vice_admin')));
$$;
grant execute on function public.mine_comm(uuid) to authenticated;


-- ── 1. 방을 만든 사람을 적어 둔다 ─────────────────────────────────
--  1:1 방을 만드는 그 한순간에는 아직 멤버 줄이 없습니다. 만든 사람을
--  적어두지 않으면, 방을 만들자마자 자기 방이 안 보이게 됩니다.
alter table public.channels add column if not exists created_by uuid;

do $$ begin
  -- 기본값을 '지금 로그인한 사람' 으로. 화면 코드를 안 고쳐도 채워집니다.
  begin
    alter table public.channels alter column created_by set default auth.uid();
  exception when others then null;   -- auth.uid() 가 없는 환경이면 건너뛴다
  end;
end $$;

create index if not exists channels_created_by_idx on public.channels (created_by);
create index if not exists channel_members_member_idx on public.channel_members (member_id);


-- ── 2. '내 채팅방' 을 진짜 내 채팅방으로 ──────────────────────────
--  총관리자·부총관리자는 그대로 전부 봅니다 (지켜보라고 있는 자리입니다).
--  나머지는 내가 들어가 있는 방 + 방금 내가 만든 방.
--
--  security definer 라서 이 안에서 channel_members 를 읽는 것은
--  정책에 걸리지 않습니다. 정책이 이 함수를 다시 부르는 돌림이 생기지 않습니다.
create or replace function public.my_channel_ids()
returns setof uuid language sql security definer stable parallel safe
set search_path = public as $$
  select c.id
    from public.channels c
   where exists (
     select 1 from public.members me
      where me.id = auth.uid()
        and coalesce(me.status, 'active') <> 'removed'
        and ( me.community_role in ('super_admin','vice_admin')
           or c.created_by = me.id
           or exists (select 1 from public.channel_members cm
                       where cm.channel_id = c.id and cm.member_id = me.id) ));
$$;
grant execute on function public.my_channel_ids() to authenticated;


-- ── 3. 누구와 1:1 을 틀 수 있나 ───────────────────────────────────
--  채팅방 규칙 그대로입니다 — 학생끼리는 안 됩니다. 그 규칙이 지금까지
--  화면에만 적혀 있었습니다. 여기로 옮깁니다.
create or replace function public.can_dm(p_other uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1
      from public.members me
      join public.members o on o.id = p_other
     where me.id = auth.uid()
       and me.id <> o.id
       and coalesce(o.status,  'active') <> 'removed'
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_id = o.community_id
             or me.community_role in ('super_admin','vice_admin') )
       -- 학생 × 학생 은 막는다. role 이 비어 있을 수 있으니 coalesce —
       -- NULL = '학생' 은 거짓이 아니라 '모름' 이라서 조건 전체를 망칩니다.
       and not ( (coalesce(me.community_role,'') = 'student' or coalesce(me.role,'') = '학생')
                 and (coalesce(o.community_role,'') = 'student' or coalesce(o.role,'') = '학생') )
       and coalesce(o.community_role,'') <> 'store_bot'
  );
$$;
grant execute on function public.can_dm(uuid) to authenticated;


-- ── 4. 방 ─────────────────────────────────────────────────────────
--  읽기 : 내가 들어간 방 + 간사 이상은 '단체방 목록' 까지 (내용은 아래 6번).
--         1:1 방은 목록조차 안 보입니다 — 누가 누구와 이야기하는지가
--         이미 사생활입니다. 총·부총관리자만 지켜봅니다.
--  만들기: 간사 이상은 자유롭게. 그 밖에는 1:1 방만, 내 이름으로.
--  고치기·지우기: 간사 이상만.
alter table public.channels enable row level security;
drop policy if exists channels_comm   on public.channels;
drop policy if exists channels_select on public.channels;
drop policy if exists channels_insert on public.channels;
drop policy if exists channels_update on public.channels;
drop policy if exists channels_delete on public.channels;

create policy channels_select on public.channels for select to authenticated
using ( id in (select public.my_channel_ids())
        or ( public.staff_of(community_id) and coalesce(kind,'topic') <> 'dm' ) );

create policy channels_insert on public.channels for insert to authenticated
with check (
  public.mine_comm(community_id)
  and ( public.staff_of(community_id)
        or ( coalesce(kind,'topic') = 'dm' and coalesce(created_by, auth.uid()) = auth.uid() ) )
);

create policy channels_update on public.channels for update to authenticated
using ( public.staff_of(community_id) ) with check ( public.staff_of(community_id) );

create policy channels_delete on public.channels for delete to authenticated
using ( public.staff_of(community_id) );

grant select, insert, update, delete on public.channels to authenticated;


-- ── 5. 방 멤버 ────────────────────────────────────────────────────
create or replace function public.can_add_channel_member(p_channel uuid, p_member uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1 from public.channels c
     where c.id = p_channel
       and ( public.staff_of(c.community_id)
             -- 1:1 방: 내가 만든 방에, 나와 상대만.
             or ( coalesce(c.kind,'topic') = 'dm'
                  and c.created_by = auth.uid()
                  and ( p_member = auth.uid() or public.can_dm(p_member) ) ) ));
$$;
grant execute on function public.can_add_channel_member(uuid, uuid) to authenticated;

alter table public.channel_members enable row level security;
drop policy if exists channel_members_comm   on public.channel_members;
drop policy if exists channel_members_select on public.channel_members;
drop policy if exists channel_members_insert on public.channel_members;
drop policy if exists channel_members_update on public.channel_members;
drop policy if exists channel_members_delete on public.channel_members;

create policy channel_members_select on public.channel_members for select to authenticated
using ( channel_id in (select public.my_channel_ids())
        or exists (select 1 from public.channels c
                    where c.id = channel_id
                      and coalesce(c.kind,'topic') <> 'dm'
                      and public.staff_of(c.community_id)) );

create policy channel_members_insert on public.channel_members for insert to authenticated
with check ( public.can_add_channel_member(channel_id, member_id) );

-- 즐겨찾기(★)는 내 줄만 건드립니다.
create policy channel_members_update on public.channel_members for update to authenticated
using      ( member_id = auth.uid() or public.can_moderate_channel(channel_id) )
with check ( member_id = auth.uid() or public.can_moderate_channel(channel_id) );

-- 내보내기는 간사 이상. 내가 나가는 것은 언제든.
create policy channel_members_delete on public.channel_members for delete to authenticated
using ( member_id = auth.uid() or public.can_moderate_channel(channel_id) );

grant select, insert, update, delete on public.channel_members to authenticated;

-- 1:1 방은 둘까지. 한 문장에 여러 줄을 밀어넣는 길을 막습니다
-- (정책의 count 는 문장 시작 시점을 보기 때문에 같은 문장 안의 줄을 못 셉니다.
--  방아쇠는 줄마다 그 자리에서 돌아서, 앞줄이 들어간 것을 봅니다.)
create or replace function public.dm_two_people() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text; n int;
begin
  select coalesce(kind,'topic') into k from public.channels where id = new.channel_id;
  if k <> 'dm' then return new; end if;
  select count(distinct member_id) into n from public.channel_members where channel_id = new.channel_id;
  if n >= 2 and not exists (select 1 from public.channel_members
                             where channel_id = new.channel_id and member_id = new.member_id) then
    raise exception '1:1 대화방에는 두 사람까지만 들어갈 수 있습니다';
  end if;
  return new;
end $$;

drop trigger if exists dm_two_people_trg on public.channel_members;
create trigger dm_two_people_trg before insert on public.channel_members
  for each row execute function public.dm_two_people();


-- ── 6. 메시지 ─────────────────────────────────────────────────────
--  정책 글은 그대로입니다. my_channel_ids() 가 좁아졌으니 같이 좁아집니다.
--  간사 이상이라도 '들어가 있지 않은 방' 의 대화는 못 읽습니다.
--  (총·부총관리자만 지켜봅니다 — 그게 지금까지의 약속이었습니다)
--  혹시 예전 정책이 남아 있으면 지웁니다. 허용 정책은 OR 로 합쳐져서,
--  하나만 남아 있어도 다 열립니다.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
            where schemaname='public' and tablename='messages'
  loop execute format('drop policy if exists %I on public.messages', p.policyname); end loop;
end $$;

alter table public.messages enable row level security;

--  한 군데만 더 엽니다: 신고된 메시지.
--  교직원이 신고함에서 처리하려면 그 한 줄은 읽을 수 있어야 합니다.
--  (가리기·지우기의 RETURNING 도 읽기 정책을 탑니다 — 안 열면 '권한이 없어요'
--   만 뜨고 신고 처리가 통째로 막힙니다. 지역에서 확인했습니다)
--  '들어가 있지 않은 방의 메시지' 중 읽히는 것은 '누군가 신고한 줄' 뿐입니다.
--  '신고된 줄인가' 는 definer 함수로 묻습니다. 정책 안에서 신고표를 직접
--  읽으면 그 표의 권한·정책에 또 매이고, 한쪽을 고칠 때 다른 쪽이 조용히
--  망가집니다. 묻는 길을 하나로 둡니다.
create or replace function public.is_reported_message(p_msg uuid)
returns boolean language plpgsql stable security definer parallel safe
set search_path = public as $$
begin
  if to_regclass('public.message_reports') is null then return false; end if;
  return exists (select 1 from public.message_reports r where r.message_id = p_msg);
end $$;
grant execute on function public.is_reported_message(uuid) to authenticated;

create policy messages_select on public.messages for select to authenticated
using ( channel_id in (select public.my_channel_ids())
        or ( public.can_moderate_channel(channel_id)
             and public.is_reported_message(id) ) );

create policy messages_insert on public.messages for insert to authenticated
with check ( sender_id = auth.uid() and channel_id in (select public.my_channel_ids()) );

create policy messages_update on public.messages for update to authenticated
using      ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) )
with check ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) );

create policy messages_delete on public.messages for delete to authenticated
using ( public.can_moderate_channel(channel_id)
        or (sender_id = auth.uid() and hidden_at is null) );

grant select, insert, update, delete on public.messages to authenticated;


-- ── 7. 지금 있는 방의 '만든 사람' 메우기 ──────────────────────────
--  옛날 방에는 created_by 가 비어 있습니다. 비어 있어도 2번 함수가
--  멤버 줄로 찾으니 문제는 없지만, 1:1 방만 첫 멤버로 메워 둡니다.
update public.channels c
   set created_by = (select cm.member_id from public.channel_members cm
                      where cm.channel_id = c.id order by cm.ctid limit 1)
 where c.created_by is null and coalesce(c.kind,'topic') = 'dm';

notify pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════════
--  🔴 10) 앱 아이콘의 빨간 숫자  (db/앱아이콘_숫자_DB설치.sql)
--
--  알림은 잘 떴는데 아이콘에 숫자가 안 붙었습니다. 보내는 쪽에서 숫자
--  칸을 아예 비워서 보내고 있었습니다. 받는 사람마다 '지금 몇 개
--  안 읽었나' 를 세어 같이 보내려면 이 함수가 필요합니다.
--  자세한 내용: docs/앱아이콘_숫자_안내.md
-- ════════════════════════════════════════════════════════════════════

create or replace function public.unread_counts(p_members uuid[])
returns table (member_id uuid, n integer)
language sql stable security definer parallel safe
set search_path = public as $$
  select cm.member_id,
         count(m.id)::int as n
    from public.channel_members cm
    left join public.channel_reads cr
           on cr.channel_id = cm.channel_id
          and cr.member_id  = cm.member_id
    left join public.messages m
           on m.channel_id = cm.channel_id
          and m.sender_id <> cm.member_id
          and m.hidden_at is null
          -- 창을 45일로 묶는다. 안 그러면 몇 해치 글을 다 세느라
          -- 알림 한 번 보낼 때마다 데이터베이스가 한참 걸린다.
          and m.created_at > now() - interval '45 days'
          and m.created_at > coalesce(cr.last_read_at, now() - interval '45 days')
   where cm.member_id = any(p_members)
   group by cm.member_id;
$$;

-- 남의 안읽음 수는 남의 사정이다. 알림 보내는 서버(service_role)만
-- 부를 수 있게 한다 — 로그인한 사람에게는 열지 않는다.
revoke all on function public.unread_counts(uuid[]) from public, anon, authenticated;
grant execute on function public.unread_counts(uuid[]) to service_role;

-- 세는 길을 빠르게
create index if not exists messages_ch_created_idx
  on public.messages (channel_id, created_at desc);
create index if not exists channel_reads_mem_ch_idx
  on public.channel_reads (member_id, channel_id);

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════
--  🔢 11) 방마다 안 읽은 글 수  (db/안읽음_방별_DB설치.sql)
--
--  채팅 목록의 빨간 숫자. 예전에는 화면이 45일치 글을 통째로 받아다
--  직접 셌는데, 서버는 한 번에 1000줄까지만 돌려줍니다. 순서를 안 정해
--  줬으니 오래된 1000개가 왔고, 정작 안 읽은 최근 글은 한 줄도 안 왔습니다.
--  그래서 방이 많은 계정에서는 모든 방이 '다 읽음' 으로 보였습니다.
--  세는 일을 데이터베이스로 옮깁니다 — 수만 받으면 잘릴 것이 없습니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.unread_by_channel()
returns table (channel_id uuid, n integer)
language sql stable security invoker parallel safe
set search_path = public as $$
  select c.id as channel_id,
         count(m.id)::int as n
    from public.channels c
    left join public.channel_reads cr
           on cr.channel_id = c.id
          and cr.member_id  = auth.uid()
    left join public.messages m
           on m.channel_id = c.id
          and m.sender_id <> auth.uid()
          and m.hidden_at is null
          -- 창을 45일로 묶는다. 화면·아이콘 숫자와 같은 기준이다.
          and m.created_at > now() - interval '45 days'
          and m.created_at > coalesce(cr.last_read_at, now() - interval '45 days')
   group by c.id;
$$;

-- 로그인한 사람만. 익명은 부를 수 없다.
revoke all on function public.unread_by_channel() from public, anon;
grant execute on function public.unread_by_channel() to authenticated;

-- 세는 길을 빠르게 (이미 있으면 그냥 넘어갑니다)
create index if not exists messages_ch_created_idx
  on public.messages (channel_id, created_at desc);
create index if not exists channel_reads_mem_ch_idx
  on public.channel_reads (member_id, channel_id);

notify pgrst, 'reload schema';

-- ────────────────────────────────────────────────────────────────────
--  다른 기기에서 읽으면 이쪽 숫자도 같이 내려가게 한다.
--
--  "아이폰에서 먼저 채팅을 확인하면 맥북에서는 숫자가 안 사라지네"
--
--  아이폰은 닫혀 있어도 애플 알림으로 아이콘 숫자를 고쳐 줄 수 있지만,
--  맥북과 브라우저에는 그 길이 없습니다. 대신 둘 다 실시간 줄에 붙어
--  있으니, '읽음' 줄이 바뀌면 그쪽에서 다시 세게 합니다.
--  내 줄만 보냅니다 — channel_reads 의 RLS 가 member_id = auth.uid()
--  이므로, 남이 무엇을 읽었는지는 애초에 안 보입니다.
-- ────────────────────────────────────────────────────────────────────
do $$
begin
  alter publication supabase_realtime add table public.channel_reads;
exception
  when duplicate_object then null;   -- 이미 들어 있으면 그냥 넘어갑니다
  when others then null;
end $$;

-- ════════════════════════════════════════════════════════════════════
--  🌐 12) 화면 언어를 사람마다 따로  (db/언어_개인별_DB설치.sql)
--
--  예전에는 공동체에 한 줄뿐이라, 관리자가 영어로 바꾸면 그 공동체
--  사람 전부가 영어로 보였습니다. 이제 각자 고릅니다.
--  안 고른 사람은 예전처럼 공동체 언어를 따릅니다.
-- ════════════════════════════════════════════════════════════════════

alter table public.members
  add column if not exists language text;

-- 'ko' 와 'en' 만 받는다. 엉뚱한 값이 들어가면 화면이 한국어로 떨어진다.
do $$
begin
  alter table public.members
    add constraint members_language_chk check (language in ('ko','en'));
exception
  when duplicate_object then null;
  when others then null;
end $$;

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════
--  ✏️ 13) 이름은 본인과 관리자만  (db/이름_바꾸기_권한.sql)
--
--  members_update 가 '역할·상태만 안 건드리면 통과' 로 열려 있어서,
--  같은 공동체면 누구나 남의 이름을 바꿀 수 있었습니다. 이름만
--  따로 잠급니다. 교사가 학생 기록을 저장하는 길은 그대로입니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.member_name_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select name from public.members where id = target;
$$;
grant execute on function public.member_name_of(uuid) to authenticated;

drop policy if exists members_name_guard on public.members;
create policy members_name_guard on public.members
  as restrictive for update to authenticated
  using ( true )
  with check (
    name is not distinct from public.member_name_of(id)   -- 이름을 안 건드렸거나
    or id = auth.uid()                                    -- 내 이름이거나
    or public.can_admin_members()                         -- 관리자이거나
  );

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════
--  👑 14) 방을 만든 사람이 방장  (db/방장_권한.sql)
--
--  지금은 교직원만 방 이름을 바꿀 수 있어서, 학생이 만든 토픽방은
--  정작 만든 본인이 이름도 못 고쳤습니다. 방장에게 '이름 바꾸기' 와
--  '내보내기' 만 줍니다. 방 지우기는 교직원만 그대로입니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.is_channel_owner(ch uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1 from public.channels c
     where c.id = ch
       and c.created_by = auth.uid()
       and coalesce(c.kind, 'topic') <> 'dm'   -- 1:1 에는 방장이 없다
  );
$$;
grant execute on function public.is_channel_owner(uuid) to authenticated;

-- ── 방 이름 바꾸기 ──
drop policy if exists channels_update on public.channels;
create policy channels_update on public.channels for update to authenticated
  using      ( public.staff_of(community_id) or public.is_channel_owner(id) )
  with check ( public.staff_of(community_id) or public.is_channel_owner(id) );

-- ── 내보내기 ──
--  나가기(본인)·교직원은 그대로. 방장이 더해집니다.
drop policy if exists channel_members_delete on public.channel_members;
create policy channel_members_delete on public.channel_members for delete to authenticated
  using (
    member_id = auth.uid()                       -- 내가 나가는 건 늘 된다
    or public.can_moderate_channel(channel_id)   -- 교직원
    or ( public.is_channel_owner(channel_id)     -- 방장
         and member_id <> auth.uid() )           -- (자기를 내보내는 건 '나가기' 로)
  );

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════
--  🗂 15) 채팅 순서·그룹을 사람마다  (db/내순서_내그룹_DB설치.sql)
--
--  예전에는 순서를 channels.sort 에 적어서, 한 사람이 옮기면 그 방을
--  보는 모두의 순서가 바뀌었습니다. 게다가 관리자만 옮길 수 있었습니다.
--  개인 덧층을 둡니다 — 공동체 기본값은 그대로, 내가 옮긴 것만 얹습니다.
-- ════════════════════════════════════════════════════════════════════

-- ── 내 그룹 ──
create table if not exists public.my_channel_groups (
  id         uuid primary key default gen_random_uuid(),
  member_id  uuid not null,
  name       text not null,
  sort       int,
  created_at timestamptz default now()
);
alter table public.my_channel_groups enable row level security;
drop policy if exists my_channel_groups_own on public.my_channel_groups;
create policy my_channel_groups_own on public.my_channel_groups
  for all to authenticated
  using ( member_id = auth.uid() ) with check ( member_id = auth.uid() );
create index if not exists my_channel_groups_mem_idx
  on public.my_channel_groups (member_id, sort);

-- ── 내가 옮긴 자리 ──
--  group_id 는 공동체 그룹(channel_groups)일 수도 내 그룹일 수도 있다.
--  그래서 외래키를 걸지 않는다. 가리키던 그룹이 사라지면 '그룹 없음'
--  으로 떨어지게 화면에서 다룬다.
create table if not exists public.my_channel_prefs (
  member_id  uuid not null,
  channel_id uuid not null,
  sort       int,
  group_id   uuid,
  updated_at timestamptz default now(),
  primary key (member_id, channel_id)
);
alter table public.my_channel_prefs enable row level security;
drop policy if exists my_channel_prefs_own on public.my_channel_prefs;
create policy my_channel_prefs_own on public.my_channel_prefs
  for all to authenticated
  using ( member_id = auth.uid() ) with check ( member_id = auth.uid() );
create index if not exists my_channel_prefs_mem_idx
  on public.my_channel_prefs (member_id);

grant select, insert, update, delete on public.my_channel_groups to authenticated;
grant select, insert, update, delete on public.my_channel_prefs  to authenticated;

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════
--  🗓 16) 개인 일정  (db/개인일정_DB설치.sql)
--
--  events.owner_id — 비어 있으면 공동체 일정(예전 것 전부), 내 id 면
--  나만 보는 일정. 개인 일정은 '남이 못 보는' 것이 요점이라
--  화면이 아니라 서버에서 막습니다.
-- ════════════════════════════════════════════════════════════════════

alter table public.events
  add column if not exists owner_id uuid;

create index if not exists events_owner_idx on public.events (owner_id);

-- ── 보기 ──
--  공동체 일정은 그 공동체 사람에게, 개인 일정은 본인에게만.
drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select to authenticated
  using (
    ( owner_id is null and public.mine_comm(community_id) )
    or owner_id = auth.uid()
  );

-- ── 만들기 ──
--  내 일정은 누구나. 공동체 일정은 예전 규칙(교직원) 그대로.
drop policy if exists events_insert on public.events;
create policy events_insert on public.events
  for insert to authenticated
  with check (
    ( owner_id = auth.uid() and public.mine_comm(community_id) )
    or ( owner_id is null and public.staff_of(community_id) )
  );

-- ── 고치기·지우기 ──
--  내 일정은 나만. 공동체 일정은 교직원.
drop policy if exists events_update on public.events;
create policy events_update on public.events
  for update to authenticated
  using      ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) )
  with check ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) );

drop policy if exists events_delete on public.events;
create policy events_delete on public.events
  for delete to authenticated
  using ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) );

alter table public.events enable row level security;
grant select, insert, update, delete on public.events to authenticated;

notify pgrst, 'reload schema';

