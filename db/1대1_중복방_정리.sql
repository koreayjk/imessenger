-- =====================================================================
--  🧹 같은 두 사람 사이에 생긴 1:1 방 합치기
--
--  왜 생겼나 — 1:1 방을 '방 이름에 두 사람 이름이 다 들어 있는지' 로
--  찾고 있었습니다. 그래서 한쪽이 이름을 바꾸면 못 찾고 새 방을 또
--  만들었습니다. 빨리 두 번 누르는 것도 같은 일을 일으켰습니다.
--  (같은 두 사람 사이에 방이 일곱 개까지 생겼습니다)
--
--  코드는 고쳤습니다 — 이제 '누가 들어 있는가' 로 찾습니다.
--  이미 쪼개진 방만 합칩니다.
--
--  ⚠️ 대화 내역을 지우지 않습니다. 가장 먼저 만든 방으로 옮겨 붙입니다.
--     ① 로 먼저 보시고, 괜찮으면 ② 를 실행하세요.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

create or replace view public.v_dm_dupes as
with pair as (
  select cm.channel_id,
         array_agg(cm.member_id order by cm.member_id) as two
    from public.channel_members cm
    join public.channels c on c.id = cm.channel_id and c.kind = 'dm'
   group by cm.channel_id
  having count(*) = 2
),
withn as (
  select p.channel_id, p.two,
         (select count(*) from public.messages m where m.channel_id = p.channel_id) as msgs,
         (select c.created_at from public.channels c where c.id = p.channel_id) as made
    from pair p
),
ranked as (
  select *,
         -- 남길 방: 대화가 가장 많은 방, 같으면 가장 먼저 만든 방
         row_number() over (partition by two order by msgs desc, made asc nulls last) as rn,
         count(*)     over (partition by two) as n
    from withn
)
select * from ranked where n > 1;

-- ── ① 먼저 봅니다 (아무것도 안 고칩니다) ───────────────────────────
select
  (select string_agg(m.name, ' · ' order by m.name)
     from public.members m where m.id = any(r.two))           as "두 사람",
  r.n                                                          as "방 개수",
  sum(r.msgs) over (partition by r.two)                        as "전체 대화 수",
  case when r.rn = 1 then '✅ 남김' else '→ 옮겨 붙임' end      as "처리",
  r.msgs                                                       as "이 방 대화",
  r.made                                                       as "만든 때"
from public.v_dm_dupes r
order by "두 사람", r.rn;

-- ── ② 실제로 합칩니다 ──────────────────────────────────────────────
do $$
declare
  v_keep uuid;
  v_dead uuid[];
  v_two  uuid[];
  v_moved int := 0;
  v_rooms int := 0;
begin
  for v_two, v_keep, v_dead in
    select two,
           (array_agg(channel_id order by rn))[1],
           (array_agg(channel_id order by rn))[2:]
      from public.v_dm_dupes group by two
  loop
    -- 대화를 남길 방으로 옮긴다
    update public.messages set channel_id = v_keep where channel_id = any(v_dead);
    get diagnostics v_moved = row_count;

    -- 읽음 표시는 옮기지 않는다. 방이 합쳐지면 다시 세는 게 맞다.
    delete from public.channel_reads where channel_id = any(v_dead);

    -- 남길 방에 두 사람이 다 들어 있게 한다.
    --  channel_members 에 유니크 제약이 없어서 on conflict 가 안 통한다.
    --  그냥 넣으면 같은 사람이 두 줄씩 생겨 '사람 4명' 인 1:1 방이 된다.
    insert into public.channel_members (channel_id, member_id)
    select v_keep, u from unnest(v_two) u
     where not exists (select 1 from public.channel_members cm
                        where cm.channel_id = v_keep and cm.member_id = u);

    -- 빈 방을 치운다 (channel_members 등은 따라 지워진다)
    delete from public.channels where id = any(v_dead);
    v_rooms := v_rooms + array_length(v_dead, 1);
    raise notice '합침: 대화 % 개를 옮기고 방 % 개를 치웠습니다',
                 v_moved, array_length(v_dead, 1);
  end loop;
  raise notice '모두 % 개의 방을 합쳤습니다', v_rooms;
end $$;

drop view if exists public.v_dm_dupes;

-- ── 겹쳐 들어간 '방 사람' 줄도 한 줄씩만 남긴다 ────────────────────
--  예전에 같은 사람이 두 번 들어간 줄이 있으면 사람 수가 부풀고,
--  알림도 두 번 갑니다.
delete from public.channel_members a
 using public.channel_members b
 where a.ctid > b.ctid
   and a.channel_id = b.channel_id
   and a.member_id  = b.member_id;

-- ── ③ 치운 뒤 확인 ────────────────────────────────────────────────
with pair as (
  select cm.channel_id, array_agg(cm.member_id order by cm.member_id) as two
    from public.channel_members cm
    join public.channels c on c.id = cm.channel_id and c.kind = 'dm'
   group by cm.channel_id having count(*) = 2
)
select count(*) as "아직 겹치는 짝"
  from (select two from pair group by two having count(*) > 1) x;

select count(*) as "남은 1:1 방" from public.channels where kind = 'dm';
