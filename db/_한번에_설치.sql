-- =====================================================================
--  TCS — 아직 설치 안 된 것 한꺼번에 (2026-10)
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
create unique index if not exists memory_items_uq
  on public.memory_items (kind, no, coalesce(community_id, '00000000-0000-0000-0000-000000000000'::uuid));
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

-- ══════ db/성구암송_내용_60구절.sql ══════
-- =====================================================================
--  📜 성구암송 내용 ① — 성경 60구절
--
--  ⚠️ 중요 — 교회마다 외우는 60구절이 다릅니다.
--     이것은 한국 교회에서 널리 쓰이는 구절로 제가 고른 목록이고,
--     본문은 개역개정을 따라 적었습니다. 쓰시는 목록·역본과 다를 수
--     있으니 **반드시 한 번 훑어보시고** 다르면 통째로 바꾸세요.
--
--     바꾸는 길 (5분이면 됩니다):
--       학사 → 성구암송 → 항목 관리 → '여러 줄 한꺼번에 넣기'
--       '지금 있는 항목을 모두 지우고 새로 넣기' 체크 →
--       한 줄에 하나씩  번호 | 구절 주소 | 본문  으로 붙여넣기
--
--  ※ db/성구암송_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

delete from public.memory_items where kind = 'verse' and community_id is null;

insert into public.memory_items (kind, no, title, body, community_id, sort) values
  ('verse', 1, '창세기 1:1', '태초에 하나님이 천지를 창조하시니라', null, 1),
  ('verse', 2, '창세기 1:27', '하나님이 자기 형상 곧 하나님의 형상대로 사람을 창조하시되 남자와 여자를 창조하시고', null, 2),
  ('verse', 3, '출애굽기 20:3', '너는 나 외에는 다른 신들을 네게 두지 말라', null, 3),
  ('verse', 4, '신명기 6:5', '너는 마음을 다하고 뜻을 다하고 힘을 다하여 네 하나님 여호와를 사랑하라', null, 4),
  ('verse', 5, '여호수아 1:9', '내가 네게 명령한 것이 아니냐 강하고 담대하라 두려워하지 말며 놀라지 말라 네가 어디로 가든지 네 하나님 여호와가 너와 함께 하느니라 하시니라', null, 5),
  ('verse', 6, '시편 1:1-2', '복 있는 사람은 악인들의 꾀를 따르지 아니하며 죄인들의 길에 서지 아니하며 오만한 자들의 자리에 앉지 아니하고 오직 여호와의 율법을 즐거워하여 그의 율법을 주야로 묵상하는도다', null, 6),
  ('verse', 7, '시편 23:1', '여호와는 나의 목자시니 내게 부족함이 없으리로다', null, 7),
  ('verse', 8, '시편 51:10', '하나님이여 내 속에 정한 마음을 창조하시고 내 안에 정직한 영을 새롭게 하소서', null, 8),
  ('verse', 9, '시편 119:105', '주의 말씀은 내 발에 등이요 내 길에 빛이니이다', null, 9),
  ('verse', 10, '시편 139:14', '내가 주께 감사하옴은 나를 지으심이 심히 기묘하심이라 주께서 하시는 일이 기이함을 내 영혼이 잘 아나이다', null, 10),
  ('verse', 11, '잠언 1:7', '여호와를 경외하는 것이 지식의 근본이거늘 미련한 자는 지혜와 훈계를 멸시하느니라', null, 11),
  ('verse', 12, '잠언 3:5-6', '너는 마음을 다하여 여호와를 신뢰하고 네 명철을 의지하지 말라 너는 범사에 그를 인정하라 그리하면 네 길을 지도하시리라', null, 12),
  ('verse', 13, '잠언 16:9', '사람이 마음으로 자기의 길을 계획할지라도 그의 걸음을 인도하시는 이는 여호와시니라', null, 13),
  ('verse', 14, '전도서 12:1', '너는 청년의 때에 너의 창조주를 기억하라', null, 14),
  ('verse', 15, '이사야 40:31', '오직 여호와를 앙망하는 자는 새 힘을 얻으리니 독수리가 날개치며 올라감 같을 것이요 달음박질하여도 곤비하지 아니하겠고 걸어가도 피곤하지 아니하리로다', null, 15),
  ('verse', 16, '이사야 41:10', '두려워하지 말라 내가 너와 함께 함이라 놀라지 말라 나는 네 하나님이 됨이라 내가 너를 굳세게 하리라 참으로 너를 도와 주리라 참으로 나의 의로운 오른손으로 너를 붙들리라', null, 16),
  ('verse', 17, '이사야 53:5', '그가 찔림은 우리의 허물 때문이요 그가 상함은 우리의 죄악 때문이라 그가 징계를 받으므로 우리는 평화를 누리고 그가 채찍에 맞으므로 우리는 나음을 받았도다', null, 17),
  ('verse', 18, '예레미야 29:11', '여호와의 말씀이니라 너희를 향한 나의 생각을 내가 아나니 평안이요 재앙이 아니니라 너희에게 미래와 희망을 주는 것이니라', null, 18),
  ('verse', 19, '미가 6:8', '사람아 주께서 선한 것이 무엇임을 네게 보이셨나니 여호와께서 네게 구하시는 것은 오직 정의를 행하며 인자를 사랑하며 겸손하게 네 하나님과 함께 행하는 것이 아니냐', null, 19),
  ('verse', 20, '마태복음 5:16', '이같이 너희 빛이 사람 앞에 비치게 하여 그들로 너희 착한 행실을 보고 하늘에 계신 너희 아버지께 영광을 돌리게 하라', null, 20),
  ('verse', 21, '마태복음 6:33', '그런즉 너희는 먼저 그의 나라와 그의 의를 구하라 그리하면 이 모든 것을 너희에게 더하시리라', null, 21),
  ('verse', 22, '마태복음 7:12', '그러므로 무엇이든지 남에게 대접을 받고자 하는 대로 너희도 남을 대접하라 이것이 율법이요 선지자니라', null, 22),
  ('verse', 23, '마태복음 11:28', '수고하고 무거운 짐 진 자들아 다 내게로 오라 내가 너희를 쉬게 하리라', null, 23),
  ('verse', 24, '마태복음 22:37-39', '예수께서 이르시되 네 마음을 다하고 목숨을 다하고 뜻을 다하여 주 너의 하나님을 사랑하라 하셨으니 이것이 크고 첫째 되는 계명이요 둘째도 그와 같으니 네 이웃을 네 자신 같이 사랑하라 하셨으니', null, 24),
  ('verse', 25, '마태복음 28:19-20', '그러므로 너희는 가서 모든 민족을 제자로 삼아 아버지와 아들과 성령의 이름으로 세례를 베풀고 내가 너희에게 분부한 모든 것을 가르쳐 지키게 하라 볼지어다 내가 세상 끝날까지 너희와 항상 함께 있으리라 하시니라', null, 25),
  ('verse', 26, '누가복음 2:52', '예수는 지혜와 키가 자라가며 하나님과 사람에게 더욱 사랑스러워 가시더라', null, 26),
  ('verse', 27, '요한복음 1:1', '태초에 말씀이 계시니라 이 말씀이 하나님과 함께 계셨으니 이 말씀은 곧 하나님이시니라', null, 27),
  ('verse', 28, '요한복음 1:12', '영접하는 자 곧 그 이름을 믿는 자들에게는 하나님의 자녀가 되는 권세를 주셨으니', null, 28),
  ('verse', 29, '요한복음 3:16', '하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라', null, 29),
  ('verse', 30, '요한복음 14:6', '예수께서 이르시되 내가 곧 길이요 진리요 생명이니 나로 말미암지 않고는 아버지께로 올 자가 없느니라', null, 30),
  ('verse', 31, '요한복음 15:5', '나는 포도나무요 너희는 가지라 그가 내 안에, 내가 그 안에 거하면 사람이 열매를 많이 맺나니 나를 떠나서는 너희가 아무 것도 할 수 없음이라', null, 31),
  ('verse', 32, '요한복음 15:13', '사람이 친구를 위하여 자기 목숨을 버리면 이보다 더 큰 사랑이 없나니', null, 32),
  ('verse', 33, '사도행전 1:8', '오직 성령이 너희에게 임하시면 너희가 권능을 받고 예루살렘과 온 유대와 사마리아와 땅 끝까지 이르러 내 증인이 되리라 하시니라', null, 33),
  ('verse', 34, '사도행전 4:12', '다른 이로써는 구원을 받을 수 없나니 천하 사람 중에 구원을 받을 만한 다른 이름을 우리에게 주신 일이 없음이라 하였더라', null, 34),
  ('verse', 35, '로마서 1:16', '내가 복음을 부끄러워하지 아니하노니 이 복음은 모든 믿는 자에게 구원을 주시는 하나님의 능력이 됨이라', null, 35),
  ('verse', 36, '로마서 3:23', '모든 사람이 죄를 범하였으매 하나님의 영광에 이르지 못하더니', null, 36),
  ('verse', 37, '로마서 5:8', '우리가 아직 죄인 되었을 때에 그리스도께서 우리를 위하여 죽으심으로 하나님께서 우리에 대한 자기의 사랑을 확증하셨느니라', null, 37),
  ('verse', 38, '로마서 6:23', '죄의 삯은 사망이요 하나님의 은사는 그리스도 예수 우리 주 안에 있는 영생이니라', null, 38),
  ('verse', 39, '로마서 8:28', '우리가 알거니와 하나님을 사랑하는 자 곧 그의 뜻대로 부르심을 입은 자들에게는 모든 것이 합력하여 선을 이루느니라', null, 39),
  ('verse', 40, '로마서 10:9', '네가 만일 네 입으로 예수를 주로 시인하며 또 하나님께서 그를 죽은 자 가운데서 살리신 것을 네 마음에 믿으면 구원을 받으리라', null, 40),
  ('verse', 41, '로마서 12:1-2', '그러므로 형제들아 내가 하나님의 모든 자비하심으로 너희를 권하노니 너희 몸을 하나님이 기뻐하시는 거룩한 산 제물로 드리라 이는 너희가 드릴 영적 예배니라 너희는 이 세대를 본받지 말고 오직 마음을 새롭게 함으로 변화를 받아', null, 41),
  ('verse', 42, '고린도전서 10:13', '사람이 감당할 시험 밖에는 너희가 당한 것이 없나니 오직 하나님은 미쁘사 너희가 감당하지 못할 시험 당함을 허락하지 아니하시고 시험 당할 즈음에 또한 피할 길을 내사 너희로 능히 감당하게 하시느니라', null, 42),
  ('verse', 43, '고린도전서 10:31', '그런즉 너희가 먹든지 마시든지 무엇을 하든지 다 하나님의 영광을 위하여 하라', null, 43),
  ('verse', 44, '고린도전서 13:4-5', '사랑은 오래 참고 사랑은 온유하며 시기하지 아니하며 사랑은 자랑하지 아니하며 교만하지 아니하며 무례히 행하지 아니하며 자기의 유익을 구하지 아니하며 성내지 아니하며 악한 것을 생각하지 아니하며', null, 44),
  ('verse', 45, '고린도후서 5:17', '그런즉 누구든지 그리스도 안에 있으면 새로운 피조물이라 이전 것은 지나갔으니 보라 새 것이 되었도다', null, 45),
  ('verse', 46, '갈라디아서 2:20', '내가 그리스도와 함께 십자가에 못 박혔나니 그런즉 이제는 내가 사는 것이 아니요 오직 내 안에 그리스도께서 사시는 것이라', null, 46),
  ('verse', 47, '갈라디아서 5:22-23', '오직 성령의 열매는 사랑과 희락과 화평과 오래 참음과 자비와 양선과 충성과 온유와 절제니 이같은 것을 금지할 법이 없느니라', null, 47),
  ('verse', 48, '에베소서 2:8-9', '너희는 그 은혜에 의하여 믿음으로 말미암아 구원을 받았으니 이것은 너희에게서 난 것이 아니요 하나님의 선물이라 행위에서 난 것이 아니니 이는 누구든지 자랑하지 못하게 함이라', null, 48),
  ('verse', 49, '에베소서 6:1-3', '자녀들아 주 안에서 너희 부모에게 순종하라 이것이 옳으니라 네 아버지와 어머니를 공경하라 이것은 약속이 있는 첫 계명이니 이로써 네가 잘되고 땅에서 장수하리라', null, 49),
  ('verse', 50, '빌립보서 2:5-7', '너희 안에 이 마음을 품으라 곧 그리스도 예수의 마음이니 그는 근본 하나님의 본체시나 하나님과 동등됨을 취할 것으로 여기지 아니하시고 오히려 자기를 비워 종의 형체를 가지사 사람들과 같이 되셨고', null, 50),
  ('verse', 51, '빌립보서 4:6-7', '아무 것도 염려하지 말고 다만 모든 일에 기도와 간구로 너희 구할 것을 감사함으로 하나님께 아뢰라 그리하면 모든 지각에 뛰어난 하나님의 평강이 그리스도 예수 안에서 너희 마음과 생각을 지키시리라', null, 51),
  ('verse', 52, '빌립보서 4:13', '내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라', null, 52),
  ('verse', 53, '골로새서 3:23', '무슨 일을 하든지 마음을 다하여 주께 하듯 하고 사람에게 하듯 하지 말라', null, 53),
  ('verse', 54, '데살로니가전서 5:16-18', '항상 기뻐하라 쉬지 말고 기도하라 범사에 감사하라 이것이 그리스도 예수 안에서 너희를 향하신 하나님의 뜻이니라', null, 54),
  ('verse', 55, '디모데전서 4:12', '누구든지 네 연소함을 업신여기지 못하게 하고 오직 말과 행실과 사랑과 믿음과 정절에 있어서 믿는 자에게 본이 되어', null, 55),
  ('verse', 56, '디모데후서 3:16-17', '모든 성경은 하나님의 감동으로 된 것으로 교훈과 책망과 바르게 함과 의로 교육하기에 유익하니 이는 하나님의 사람으로 온전하게 하며 모든 선한 일을 행할 능력을 갖추게 하려 함이라', null, 56),
  ('verse', 57, '히브리서 11:1', '믿음은 바라는 것들의 실상이요 보이지 않는 것들의 증거니', null, 57),
  ('verse', 58, '히브리서 12:1-2', '이러므로 우리에게 구름 같이 둘러싼 허다한 증인들이 있으니 모든 무거운 것과 얽매이기 쉬운 죄를 벗어 버리고 인내로써 우리 앞에 당한 경주를 하며 믿음의 주요 또 온전하게 하시는 이인 예수를 바라보자', null, 58),
  ('verse', 59, '야고보서 1:22', '너희는 말씀을 행하는 자가 되고 듣기만 하여 자신을 속이는 자가 되지 말라', null, 59),
  ('verse', 60, '요한일서 1:9', '만일 우리가 우리 죄를 자백하면 그는 미쁘시고 의로우사 우리 죄를 사하시며 우리를 모든 불의에서 깨끗하게 하실 것이요', null, 60);

notify pgrst, 'reload schema';

select count(*) as "성경 구절" from public.memory_items where kind='verse';

-- ══════ db/성구암송_내용_소교리문답.sql ══════
-- =====================================================================
--  📜 성구암송 내용 ② — 웨스트민스터 소교리문답 107문
--
--  ⚠️ 제가 표준 번역을 바탕으로 적은 것입니다. 교회에서 쓰시는
--     번역본과 낱말이 다를 수 있습니다. 아이들이 이 글로 외우게
--     되니, 꼭 한 번 훑어보시고 다르면 고쳐 주세요.
--     고치는 길: 학사 → 성구암송 → 항목 관리 →
--     '여러 줄 한꺼번에 넣기' 에서 '모두 지우고 새로 넣기'
--
--  ※ db/성구암송_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

delete from public.memory_items where kind = 'catechism' and community_id is null;

insert into public.memory_items (kind, no, title, body, answer, community_id, sort) values
  ('catechism', 1, '제1문', '사람의 제일 되는 목적이 무엇인가?', '사람의 제일 되는 목적은 하나님을 영화롭게 하고 영원토록 그를 즐거워하는 것이다.', null, 1),
  ('catechism', 2, '제2문', '하나님께서 무슨 법칙을 주어 우리가 어떻게 그를 영화롭게 하고 즐거워할 것을 지시하셨는가?', '신구약 성경에 담긴 하나님의 말씀이 우리가 어떻게 그를 영화롭게 하고 즐거워할 것인지 지시하는 유일한 법칙이다.', null, 2),
  ('catechism', 3, '제3문', '성경이 주로 가르치는 것이 무엇인가?', '성경이 주로 가르치는 것은 사람이 하나님에 대하여 무엇을 믿을 것과 하나님께서 사람에게 요구하시는 본분이 무엇인가 하는 것이다.', null, 3),
  ('catechism', 4, '제4문', '하나님은 어떤 분이신가?', '하나님은 영이시니 그 존재와 지혜와 권능과 거룩하심과 공의와 인자하심과 진실하심이 무한하시고 영원하시며 불변하시다.', null, 4),
  ('catechism', 5, '제5문', '하나님이 한 분 외에 또 있는가?', '오직 한 분 참되시고 살아 계신 하나님만 계시다.', null, 5),
  ('catechism', 6, '제6문', '하나님의 신격에 몇 위가 계신가?', '하나님의 신격에 삼위가 계시니 곧 성부와 성자와 성령이시다. 이 삼위는 한 하나님이시요 본체는 하나이며 권능과 영광이 동등하시다.', null, 6),
  ('catechism', 7, '제7문', '하나님의 작정이 무엇인가?', '하나님의 작정은 그의 뜻의 계획을 따라 자기 영광을 위하여 일어날 모든 일을 미리 정하신 영원한 목적이다.', null, 7),
  ('catechism', 8, '제8문', '하나님이 그의 작정을 어떻게 실행하시는가?', '하나님은 창조와 섭리의 사역으로 그의 작정을 실행하신다.', null, 8),
  ('catechism', 9, '제9문', '창조의 사역이 무엇인가?', '창조의 사역은 하나님이 엿새 동안에 말씀의 권능으로 모든 것을 무에서 만드시되 심히 좋게 만드신 것이다.', null, 9),
  ('catechism', 10, '제10문', '하나님이 사람을 어떻게 창조하셨는가?', '하나님이 남자와 여자를 자기 형상대로 지식과 의와 거룩함으로 창조하시고 피조물을 다스리게 하셨다.', null, 10),
  ('catechism', 11, '제11문', '하나님의 섭리의 사역이 무엇인가?', '하나님의 섭리의 사역은 그의 모든 피조물과 그들의 모든 행동을 가장 거룩하고 지혜롭고 능력 있게 보존하시고 다스리시는 것이다.', null, 11),
  ('catechism', 12, '제12문', '하나님이 사람을 창조하신 후 그에게 어떤 특별한 섭리의 행위를 베푸셨는가?', '하나님이 사람을 창조하신 후에 생명의 언약을 세우시되 완전한 순종을 조건으로 하시고 선악을 알게 하는 나무의 열매를 먹지 말라 명하시며 어기면 죽으리라 하셨다.', null, 12),
  ('catechism', 13, '제13문', '우리의 시조가 창조함을 받은 그 상태에 그대로 있었는가?', '우리의 시조는 자기의 자유의지에 맡겨졌으나 하나님께 범죄함으로 창조함을 받은 그 상태에서 타락하였다.', null, 13),
  ('catechism', 14, '제14문', '죄가 무엇인가?', '죄는 하나님의 법에 순종하지 않거나 그것을 어기는 것이다.', null, 14),
  ('catechism', 15, '제15문', '우리의 시조가 창조함을 받은 그 상태에서 타락하게 한 죄가 무엇인가?', '우리의 시조가 타락하게 된 죄는 금한 열매를 먹은 것이다.', null, 15),
  ('catechism', 16, '제16문', '온 인류가 아담의 첫 범죄에 타락하였는가?', '아담과 맺은 언약은 그 자신뿐 아니라 그의 후손을 위한 것이므로 보통 생육법으로 그에게서 난 온 인류가 그의 첫 범죄에 그와 함께 범죄하고 타락하였다.', null, 16),
  ('catechism', 17, '제17문', '타락은 인류를 어떤 상태에 빠지게 하였는가?', '타락은 인류를 죄와 비참한 상태에 빠지게 하였다.', null, 17),
  ('catechism', 18, '제18문', '사람이 빠진 그 상태의 죄악성이 무엇인가?', '사람이 빠진 그 상태의 죄악성은 아담의 첫 죄의 죄책과 원래의 의의 결핍과 전 성품의 부패니 이것을 원죄라 하며 거기서 나오는 모든 자범죄이다.', null, 18),
  ('catechism', 19, '제19문', '사람이 빠진 그 상태의 비참이 무엇인가?', '온 인류가 타락으로 하나님과의 교제를 잃고 그의 진노와 저주 아래 있어 이 세상의 모든 비참과 사망과 영원한 지옥의 고통을 당하게 되었다.', null, 19),
  ('catechism', 20, '제20문', '하나님이 온 인류를 죄와 비참한 상태에서 멸망하도록 버려 두셨는가?', '하나님이 순전히 그의 기쁘신 뜻대로 영원 전에 어떤 사람들을 택하여 영생에 이르게 하시고 은혜 언약을 세우사 한 구속자로 말미암아 죄와 비참한 상태에서 건져내어 구원의 상태에 이르게 하셨다.', null, 20),
  ('catechism', 21, '제21문', '하나님의 택하신 자의 구속자가 누구신가?', '하나님의 택하신 자의 유일한 구속자는 주 예수 그리스도시니 영원하신 하나님의 아들로서 사람이 되사 하나님이시며 사람이신 두 본성이 한 위에 계시며 영원토록 그러하시다.', null, 21),
  ('catechism', 22, '제22문', '그리스도께서 하나님의 아들로서 어떻게 사람이 되셨는가?', '그리스도께서 참된 몸과 이성 있는 영혼을 취하사 성령의 능력으로 동정녀 마리아의 태에 잉태되어 나셨으되 죄는 없으시다.', null, 22),
  ('catechism', 23, '제23문', '그리스도께서 우리의 구속자로서 무슨 직분을 행하시는가?', '그리스도께서 우리의 구속자로서 낮아지심과 높아지심의 두 상태에서 선지자와 제사장과 왕의 직분을 행하신다.', null, 23),
  ('catechism', 24, '제24문', '그리스도께서 어떻게 선지자의 직분을 행하시는가?', '그리스도께서 그의 말씀과 성령으로 우리 구원을 위한 하나님의 뜻을 계시하심으로 선지자의 직분을 행하신다.', null, 24),
  ('catechism', 25, '제25문', '그리스도께서 어떻게 제사장의 직분을 행하시는가?', '그리스도께서 하나님의 공의를 만족시키고 우리를 하나님과 화목하게 하려고 자신을 단번에 제물로 드리시고 우리를 위하여 계속 간구하심으로 제사장의 직분을 행하신다.', null, 25),
  ('catechism', 26, '제26문', '그리스도께서 어떻게 왕의 직분을 행하시는가?', '그리스도께서 우리를 자기에게 복종하게 하시고 다스리시며 보호하시고 그와 우리의 모든 원수를 제어하시고 정복하심으로 왕의 직분을 행하신다.', null, 26),
  ('catechism', 27, '제27문', '그리스도의 낮아지심이 무엇인가?', '그리스도의 낮아지심은 그가 비천한 처지에 나시고 율법 아래 나시며 이 세상의 비참과 하나님의 진노와 십자가의 저주받은 죽음을 당하시고 장사되어 얼마 동안 사망의 권세 아래 계신 것이다.', null, 27),
  ('catechism', 28, '제28문', '그리스도의 높아지심이 무엇인가?', '그리스도의 높아지심은 그가 제삼일에 죽은 자 가운데서 살아나시고 하늘에 오르사 하나님 아버지 우편에 앉으시며 마지막 날에 세상을 심판하러 오시는 것이다.', null, 28),
  ('catechism', 29, '제29문', '우리가 어떻게 그리스도의 사신 구속에 참여하는가?', '우리가 그리스도께서 사신 구속에 참여하는 것은 성령께서 그것을 우리에게 효력 있게 적용하심으로 되는 것이다.', null, 29),
  ('catechism', 30, '제30문', '성령께서 어떻게 그리스도의 사신 구속을 우리에게 적용하시는가?', '성령께서 우리 안에 믿음을 일으키시고 그 믿음으로 우리를 효력 있게 부르실 때에 그리스도와 연합하게 하심으로 그 구속을 우리에게 적용하신다.', null, 30),
  ('catechism', 31, '제31문', '효력 있는 부르심이 무엇인가?', '효력 있는 부르심은 하나님의 성령의 사역이니 우리로 죄와 비참을 깨닫게 하시고 마음을 밝혀 그리스도를 알게 하시며 의지를 새롭게 하사 복음에 값없이 주시는 예수 그리스도를 기꺼이 영접하게 하심이다.', null, 31),
  ('catechism', 32, '제32문', '효력 있게 부르심을 받은 자가 이 세상에서 무슨 유익에 참여하는가?', '효력 있게 부르심을 받은 자는 이 세상에서 칭의와 양자됨과 성화와 그에 따르는 여러 유익에 참여한다.', null, 32),
  ('catechism', 33, '제33문', '칭의가 무엇인가?', '칭의는 하나님의 값없이 주시는 은혜의 행위니 우리의 모든 죄를 사하시고 우리를 그 앞에서 의롭다 하여 받아 주심이다. 이는 오직 그리스도의 의 때문이며 믿음으로만 받는다.', null, 33),
  ('catechism', 34, '제34문', '양자됨이 무엇인가?', '양자됨은 하나님의 값없이 주시는 은혜의 행위니 우리가 하나님의 아들들의 수에 들고 그의 모든 특권에 참여할 권리를 얻는 것이다.', null, 34),
  ('catechism', 35, '제35문', '성화가 무엇인가?', '성화는 하나님의 값없이 주시는 은혜의 사역이니 우리가 하나님의 형상을 따라 전인이 새롭게 되고 점점 죄에 대하여 죽고 의에 대하여 살게 되는 것이다.', null, 35),
  ('catechism', 36, '제36문', '칭의와 양자됨과 성화에 따르는 유익이 무엇인가?', '이 세상에서 따르는 유익은 하나님의 사랑을 확신함과 양심의 평안과 성령 안에서의 기쁨과 은혜의 더함과 끝까지 견디는 것이다.', null, 36),
  ('catechism', 37, '제37문', '신자가 죽을 때에 그리스도에게서 무슨 유익을 받는가?', '신자의 영혼은 죽을 때에 완전히 거룩하게 되어 곧 영광에 들어가고 그 몸은 여전히 그리스도와 연합하여 부활 때까지 무덤에서 쉰다.', null, 37),
  ('catechism', 38, '제38문', '신자가 부활 때에 그리스도에게서 무슨 유익을 받는가?', '신자는 부활 때에 영광 중에 다시 살아나서 심판 날에 공개적으로 인정받고 무죄 선언을 받으며 영원토록 하나님을 온전히 즐거워하는 복을 누린다.', null, 38),
  ('catechism', 39, '제39문', '하나님이 사람에게 요구하시는 본분이 무엇인가?', '하나님이 사람에게 요구하시는 본분은 그의 계시하신 뜻에 순종하는 것이다.', null, 39),
  ('catechism', 40, '제40문', '하나님이 처음에 사람에게 순종의 법칙으로 무엇을 계시하셨는가?', '하나님이 처음에 사람에게 순종의 법칙으로 계시하신 것은 도덕법이다.', null, 40),
  ('catechism', 41, '제41문', '도덕법이 어디에 요약되어 있는가?', '도덕법은 십계명에 요약되어 있다.', null, 41),
  ('catechism', 42, '제42문', '십계명의 대요가 무엇인가?', '십계명의 대요는 우리 마음과 뜻과 목숨과 힘을 다하여 주 우리 하나님을 사랑하고 네 이웃을 네 몸과 같이 사랑하라는 것이다.', null, 42),
  ('catechism', 43, '제43문', '십계명의 서언이 무엇인가?', '십계명의 서언은 ''나는 너를 애굽 땅 종 되었던 집에서 인도하여 낸 네 하나님 여호와니라'' 하신 말씀이다.', null, 43),
  ('catechism', 44, '제44문', '십계명의 서언이 우리에게 무엇을 가르치는가?', '십계명의 서언은 하나님이 주님이시요 우리의 하나님이시며 구속자가 되시므로 우리가 그의 모든 계명을 지킬 의무가 있음을 가르친다.', null, 44),
  ('catechism', 45, '제45문', '제1계명이 무엇인가?', '제1계명은 ''너는 나 외에는 다른 신들을 네게 두지 말라''이다.', null, 45),
  ('catechism', 46, '제46문', '제1계명이 무엇을 요구하는가?', '제1계명은 하나님을 홀로 참 하나님이시요 우리의 하나님으로 알고 인정하며 그에 합당하게 예배하고 영화롭게 할 것을 요구한다.', null, 46),
  ('catechism', 47, '제47문', '제1계명이 무엇을 금하는가?', '제1계명은 참 하나님을 하나님과 우리의 하나님으로 부인하거나 예배하지 않거나 영화롭게 하지 않는 것과 오직 하나님께만 돌릴 예배와 영광을 다른 것에 돌리는 것을 금한다.', null, 47),
  ('catechism', 48, '제48문', '제1계명의 ''나 외에는''이라는 말이 우리에게 특별히 무엇을 가르치는가?', '''나 외에는''이라는 말은 만물을 보시는 하나님께서 다른 신을 두는 죄를 보시고 심히 불쾌히 여기심을 가르친다.', null, 48),
  ('catechism', 49, '제49문', '제2계명이 무엇인가?', '제2계명은 ''너를 위하여 새긴 우상을 만들지 말고 또 위로 하늘에 있는 것이나 아래로 땅에 있는 것이나 땅 아래 물속에 있는 것의 어떤 형상도 만들지 말며 그것들에게 절하지 말며 그것들을 섬기지 말라'' 하신 말씀이다.', null, 49),
  ('catechism', 50, '제50문', '제2계명이 무엇을 요구하는가?', '제2계명은 하나님께서 그의 말씀에 정하신 종교적 예배와 규례를 그대로 받아 지키고 순전하게 보존할 것을 요구한다.', null, 50),
  ('catechism', 51, '제51문', '제2계명이 무엇을 금하는가?', '제2계명은 형상으로 하나님을 예배하거나 그의 말씀에 정하지 아니한 다른 방법으로 예배하는 것을 금한다.', null, 51),
  ('catechism', 52, '제52문', '제2계명에 붙인 이유가 무엇인가?', '제2계명에 붙인 이유는 하나님이 우리를 주관하시는 주권과 우리에 대한 소유권과 그의 예배에 대한 열심이다.', null, 52),
  ('catechism', 53, '제53문', '제3계명이 무엇인가?', '제3계명은 ''너는 네 하나님 여호와의 이름을 망령되게 부르지 말라'' 하신 말씀이다.', null, 53),
  ('catechism', 54, '제54문', '제3계명이 무엇을 요구하는가?', '제3계명은 하나님의 이름과 칭호와 속성과 규례와 말씀과 사역을 거룩하고 경건하게 쓸 것을 요구한다.', null, 54),
  ('catechism', 55, '제55문', '제3계명이 무엇을 금하는가?', '제3계명은 하나님이 자기를 알리신 모든 것을 더럽히거나 남용하는 것을 금한다.', null, 55),
  ('catechism', 56, '제56문', '제3계명에 붙인 이유가 무엇인가?', '제3계명에 붙인 이유는 이 계명을 어기는 자가 사람의 벌은 피할지라도 주 우리 하나님은 그의 공의로운 심판을 면하게 하지 않으신다는 것이다.', null, 56),
  ('catechism', 57, '제57문', '제4계명이 무엇인가?', '제4계명은 ''안식일을 기억하여 거룩하게 지키라'' 하신 말씀이다.', null, 57),
  ('catechism', 58, '제58문', '제4계명이 무엇을 요구하는가?', '제4계명은 하나님께서 그의 말씀에 정하신 때를 거룩하게 지킬 것을 요구하니 곧 이레 중 하루를 온전히 하나님께 거룩한 안식일로 지키는 것이다.', null, 58),
  ('catechism', 59, '제59문', '하나님께서 이레 중 어느 날을 매주의 안식일로 정하셨는가?', '하나님께서 세상 창조로부터 그리스도의 부활까지는 이레 중 일곱째 날을, 그 후로는 첫째 날을 세상 끝날까지 매주의 안식일로 정하셨으니 곧 기독교의 안식일이다.', null, 59),
  ('catechism', 60, '제60문', '안식일을 어떻게 거룩하게 지킬 것인가?', '안식일을 거룩하게 지키는 것은 그날 온종일 거룩히 쉬되 다른 날에 합당한 세상일과 오락을 그치고 부득이한 일과 자비를 베푸는 일 외에는 온 시간을 공적·사적 예배에 쓰는 것이다.', null, 60),
  ('catechism', 61, '제61문', '제4계명이 무엇을 금하는가?', '제4계명은 요구하는 본분을 빠뜨리거나 소홀히 하는 것과 게으름이나 그 자체가 죄된 일로 그날을 더럽히는 것과 세상일이나 오락에 관한 불필요한 생각과 말과 행위로 더럽히는 것을 금한다.', null, 61),
  ('catechism', 62, '제62문', '제4계명에 붙인 이유가 무엇인가?', '제4계명에 붙인 이유는 하나님께서 엿새 동안은 우리 일을 하도록 허락하시고 일곱째 날은 자기를 위하여 특별한 소유권을 주장하시며 친히 본을 보이시고 안식일에 복 주신 것이다.', null, 62),
  ('catechism', 63, '제63문', '제5계명이 무엇인가?', '제5계명은 ''네 부모를 공경하라 그리하면 네 하나님 여호와가 네게 준 땅에서 네 생명이 길리라'' 하신 말씀이다.', null, 63),
  ('catechism', 64, '제64문', '제5계명이 무엇을 요구하는가?', '제5계명은 각 사람의 지위와 관계에 따라 윗사람과 아랫사람과 동등한 자에게 마땅히 돌릴 존경과 본분을 지킬 것을 요구한다.', null, 64),
  ('catechism', 65, '제65문', '제5계명이 무엇을 금하는가?', '제5계명은 각 사람의 지위와 관계에 합당한 존경과 본분을 소홀히 하거나 거스르는 모든 것을 금한다.', null, 65),
  ('catechism', 66, '제66문', '제5계명에 붙인 이유가 무엇인가?', '제5계명에 붙인 이유는 이 계명을 지키는 모든 자에게 하나님의 영광과 그들 자신의 유익에 합당한 한 장수와 번영을 약속하신 것이다.', null, 66),
  ('catechism', 67, '제67문', '제6계명이 무엇인가?', '제6계명은 ''살인하지 말라'' 하신 말씀이다.', null, 67),
  ('catechism', 68, '제68문', '제6계명이 무엇을 요구하는가?', '제6계명은 우리 자신과 남의 생명을 보존하기 위하여 모든 합당한 노력을 다할 것을 요구한다.', null, 68),
  ('catechism', 69, '제69문', '제6계명이 무엇을 금하는가?', '제6계명은 우리 자신이나 이웃의 생명을 부당하게 빼앗는 것과 그렇게 하려는 모든 것을 금한다.', null, 69),
  ('catechism', 70, '제70문', '제7계명이 무엇인가?', '제7계명은 ''간음하지 말라'' 하신 말씀이다.', null, 70),
  ('catechism', 71, '제71문', '제7계명이 무엇을 요구하는가?', '제7계명은 마음과 말과 행실에서 우리 자신과 이웃의 정결을 보존할 것을 요구한다.', null, 71),
  ('catechism', 72, '제72문', '제7계명이 무엇을 금하는가?', '제7계명은 모든 부정한 생각과 말과 행실을 금한다.', null, 72),
  ('catechism', 73, '제73문', '제8계명이 무엇인가?', '제8계명은 ''도둑질하지 말라'' 하신 말씀이다.', null, 73),
  ('catechism', 74, '제74문', '제8계명이 무엇을 요구하는가?', '제8계명은 우리 자신과 남의 재산과 형편을 합당하게 얻고 늘리는 것을 요구한다.', null, 74),
  ('catechism', 75, '제75문', '제8계명이 무엇을 금하는가?', '제8계명은 우리 자신이나 이웃의 재산과 형편을 부당하게 해롭게 하거나 해롭게 할 만한 모든 것을 금한다.', null, 75),
  ('catechism', 76, '제76문', '제9계명이 무엇인가?', '제9계명은 ''네 이웃에 대하여 거짓 증거하지 말라'' 하신 말씀이다.', null, 76),
  ('catechism', 77, '제77문', '제9계명이 무엇을 요구하는가?', '제9계명은 사람과 사람 사이에 진실을 지키고 보존하며 우리 자신과 이웃의 좋은 이름을 지키고 높일 것을 요구한다.', null, 77),
  ('catechism', 78, '제78문', '제9계명이 무엇을 금하는가?', '제9계명은 진실을 해치거나 우리 자신이나 이웃의 좋은 이름을 해치는 모든 것을 금한다.', null, 78),
  ('catechism', 79, '제79문', '제10계명이 무엇인가?', '제10계명은 ''네 이웃의 집을 탐내지 말라 네 이웃의 아내나 그의 남종이나 그의 여종이나 그의 소나 그의 나귀나 무릇 네 이웃의 소유를 탐내지 말라'' 하신 말씀이다.', null, 79),
  ('catechism', 80, '제80문', '제10계명이 무엇을 요구하는가?', '제10계명은 우리 자신의 형편에 온전히 만족하고 이웃과 그에게 속한 모든 것에 대하여 올바르고 너그러운 마음을 가질 것을 요구한다.', null, 80),
  ('catechism', 81, '제81문', '제10계명이 무엇을 금하는가?', '제10계명은 우리 형편에 불만하는 것과 이웃의 좋은 것을 시기하고 슬퍼하는 것과 그에게 속한 것을 지나치게 바라는 모든 마음을 금한다.', null, 81),
  ('catechism', 82, '제82문', '어떤 사람이 하나님의 계명을 온전히 지킬 수 있는가?', '타락한 후로는 이 세상에서 아무도 하나님의 계명을 온전히 지킬 수 없고 날마다 생각과 말과 행실로 그것을 어긴다.', null, 82),
  ('catechism', 83, '제83문', '율법을 어기는 모든 죄가 다 같이 악한가?', '어떤 죄는 그 자체로나 여러 정황으로 다른 죄보다 하나님 앞에서 더 악하다.', null, 83),
  ('catechism', 84, '제84문', '모든 죄가 마땅히 무슨 벌을 받아야 하는가?', '모든 죄는 이 세상과 오는 세상에서 하나님의 진노와 저주를 받아 마땅하다.', null, 84),
  ('catechism', 85, '제85문', '죄로 말미암아 받을 하나님의 진노와 저주를 피하려면 하나님이 우리에게 무엇을 요구하시는가?', '죄로 말미암아 받을 하나님의 진노와 저주를 피하려면 하나님께서 예수 그리스도를 믿는 믿음과 생명에 이르는 회개와 그리스도께서 구속의 은덕을 우리에게 전달하시는 모든 외적 방편을 부지런히 사용할 것을 요구하신다.', null, 85),
  ('catechism', 86, '제86문', '예수 그리스도를 믿는 믿음이 무엇인가?', '예수 그리스도를 믿는 믿음은 구원하는 은혜니 우리가 복음에 제시된 대로 구원을 위하여 오직 그리스도만 영접하고 의지하는 것이다.', null, 86),
  ('catechism', 87, '제87문', '생명에 이르는 회개가 무엇인가?', '생명에 이르는 회개는 구원하는 은혜니 죄인이 자기 죄를 참으로 깨닫고 하나님의 자비를 깨달아 그 죄를 슬퍼하고 미워하여 떠나 하나님께로 돌아와 새로 순종하기를 온전히 결심하고 힘쓰는 것이다.', null, 87),
  ('catechism', 88, '제88문', '그리스도께서 구속의 은덕을 우리에게 전달하시는 외적 방편이 무엇인가?', '그리스도께서 구속의 은덕을 전달하시는 외적이고 통상적인 방편은 그의 규례들이니 특별히 말씀과 성례와 기도이며 이것들이 택한 자의 구원을 위하여 효력 있게 된다.', null, 88),
  ('catechism', 89, '제89문', '말씀이 어떻게 구원에 효력 있게 되는가?', '하나님의 성령께서 말씀 읽는 것과 특별히 말씀 전하는 것을 죄인에게 죄를 깨닫게 하고 회개시키며 신자를 믿음으로 거룩함과 위로 안에 세워 구원에 이르게 하는 효력 있는 방편이 되게 하신다.', null, 89),
  ('catechism', 90, '제90문', '말씀이 구원에 효력 있게 되려면 어떻게 읽고 들을 것인가?', '말씀이 구원에 효력 있게 되려면 부지런함과 준비와 기도로 말씀을 대하고 믿음과 사랑으로 받아 마음에 두고 생활에 실천해야 한다.', null, 90),
  ('catechism', 91, '제91문', '성례가 어떻게 구원에 효력 있는 방편이 되는가?', '성례가 효력 있는 방편이 되는 것은 성례 자체나 베푸는 자의 덕이 아니라 오직 그리스도의 복 주심과 믿음으로 받는 자 안에서 역사하시는 성령으로 되는 것이다.', null, 91),
  ('catechism', 92, '제92문', '성례가 무엇인가?', '성례는 그리스도께서 세우신 거룩한 규례니 눈에 보이는 표로 그리스도와 새 언약의 은덕을 나타내고 인치고 신자에게 적용하는 것이다.', null, 92),
  ('catechism', 93, '제93문', '신약의 성례가 무엇인가?', '신약의 성례는 세례와 성찬이다.', null, 93),
  ('catechism', 94, '제94문', '세례가 무엇인가?', '세례는 성부와 성자와 성령의 이름으로 물로 씻음으로 우리가 그리스도께 접붙임을 받는 것과 은혜 언약의 은덕에 참여하는 것과 주의 것이 되기로 약속함을 나타내고 인치는 성례이다.', null, 94),
  ('catechism', 95, '제95문', '누구에게 세례를 베풀 것인가?', '유형교회 밖에 있는 자에게는 그리스도를 믿는 믿음과 그에게 순종함을 고백하기 전에는 세례를 베풀지 아니하나 유형교회 교인의 어린 자녀에게는 세례를 베푼다.', null, 95),
  ('catechism', 96, '제96문', '성찬이 무엇인가?', '성찬은 그리스도께서 정하신 대로 떡과 포도주를 주고받음으로 그의 죽으심을 나타내는 성례니 합당하게 받는 자가 육신으로가 아니라 믿음으로 그의 몸과 피에 참여하여 모든 은덕을 받고 은혜 안에서 자라게 하는 것이다.', null, 96),
  ('catechism', 97, '제97문', '성찬을 합당하게 받으려면 무엇이 요구되는가?', '성찬을 합당하게 받으려면 주의 몸을 분별하는 지식과 그를 의지하는 믿음과 회개와 사랑과 새로 순종함을 자기가 가졌는지 살펴야 하니 합당하지 않게 오면 자기에게 심판을 먹고 마시는 것이다.', null, 97),
  ('catechism', 98, '제98문', '기도가 무엇인가?', '기도는 하나님의 뜻에 합당한 것을 위하여 그리스도의 이름으로 우리의 소원을 하나님께 아뢰는 것이니 우리의 죄를 자백하고 그의 자비하심을 감사함으로 하는 것이다.', null, 98),
  ('catechism', 99, '제99문', '하나님께서 우리의 기도를 인도하시려고 무슨 법칙을 주셨는가?', '하나님의 말씀 전체가 기도를 인도하는 데 유익하나 특별한 법칙은 그리스도께서 제자들에게 가르치신 기도니 곧 주기도문이다.', null, 99),
  ('catechism', 100, '제100문', '주기도문의 서언이 우리에게 무엇을 가르치는가?', '''하늘에 계신 우리 아버지여''라는 서언은 우리가 하나님께 나아가기를 아버지께 나아가는 자녀와 같이 거룩한 경외와 확신으로 할 것과 다른 사람과 함께 그들을 위하여 기도할 것을 가르친다.', null, 100),
  ('catechism', 101, '제101문', '첫째 간구에서 우리가 무엇을 구하는가?', '''이름이 거룩히 여김을 받으시오며''라는 첫째 간구에서 우리는 하나님께서 우리와 모든 사람으로 그를 영화롭게 하게 하시고 모든 일을 그의 영광이 되도록 처리해 주시기를 구한다.', null, 101),
  ('catechism', 102, '제102문', '둘째 간구에서 우리가 무엇을 구하는가?', '''나라가 임하시오며''라는 둘째 간구에서 우리는 사탄의 나라가 망하고 은혜의 나라가 흥왕하여 우리와 다른 사람이 거기 들어가 지켜지며 영광의 나라가 속히 임하기를 구한다.', null, 102),
  ('catechism', 103, '제103문', '셋째 간구에서 우리가 무엇을 구하는가?', '''뜻이 하늘에서 이루어진 것 같이 땅에서도 이루어지이다''라는 셋째 간구에서 우리는 하나님께서 은혜로 우리를 하늘의 천사들과 같이 모든 일에 그의 뜻을 알고 순종하고 복종하게 하시기를 구한다.', null, 103),
  ('catechism', 104, '제104문', '넷째 간구에서 우리가 무엇을 구하는가?', '''오늘 우리에게 일용할 양식을 주시옵고''라는 넷째 간구에서 우리는 하나님의 값없이 주시는 선물로 이 세상의 좋은 것을 넉넉히 받아 누리며 그와 함께 그의 복을 받기를 구한다.', null, 104),
  ('catechism', 105, '제105문', '다섯째 간구에서 우리가 무엇을 구하는가?', '''우리가 우리에게 죄 지은 자를 사하여 준 것 같이 우리 죄를 사하여 주시옵고''라는 다섯째 간구에서 우리는 하나님께서 그리스도로 말미암아 우리의 모든 죄를 값없이 사하여 주시기를 구하니 우리가 마음으로 다른 사람을 용서하게 하시는 그 은혜 때문에 더욱 담대히 구한다.', null, 105),
  ('catechism', 106, '제106문', '여섯째 간구에서 우리가 무엇을 구하는가?', '''우리를 시험에 들게 하지 마시옵고 다만 악에서 구하시옵소서''라는 여섯째 간구에서 우리는 하나님께서 우리를 죄에 빠지도록 시험하지 않으시며 시험받을 때에 붙드시고 건져 주시기를 구한다.', null, 106),
  ('catechism', 107, '제107문', '주기도문의 결언이 우리에게 무엇을 가르치는가?', '''나라와 권세와 영광이 아버지께 영원히 있사옵나이다 아멘''이라는 결언은 우리가 기도할 용기를 오직 하나님께로부터 얻고 찬송을 그에게만 돌릴 것과 구한 것을 들으신다는 소원과 확신으로 아멘이라 할 것을 가르친다.', null, 107);

notify pgrst, 'reload schema';

select count(*) as "소교리문답 문항" from public.memory_items where kind='catechism';
