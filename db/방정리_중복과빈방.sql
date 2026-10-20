-- ════════════════════════════════════════════════════════════════════
--  🧹 채팅 목록 정리 — 겹친 1:1 방 합치기 + 빈 1:1 방 치우기
--
--  ① 같은 사람과의 1:1 방이 여러 개 — 옛날에 방을 '이름' 으로 찾던
--     탓입니다. 코드는 이미 고쳤지만(이제 '누가 들어 있는가' 로
--     찾습니다) 그때 생긴 방들이 그대로 남아 있습니다.
--     ⚠️ 대화는 지우지 않습니다. 가장 많이 쓴 방으로 옮겨 붙입니다.
--
--  ② 말 한마디 없는 1:1 방 — 눌러만 보고 닫은 방입니다.
--     앞으로는 앱이 알아서 치웁니다(떠날 때). 지금까지 쌓인 것만
--     여기서 비웁니다.
--
--  ⚠️ 단체방(토픽)은 건드리지 않습니다. 선생님이 미리 만들어 두고
--     아직 말을 안 올린 방일 수 있습니다. 맨 아래에서 '보여만' 드리니
--     보고 직접 지우세요.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

-- ── ① 겹친 1:1 방 합치기 ──────────────────────────────────────────
create or replace view public.v_dm_dupes as
with pair as (
  select cm.channel_id,
         array_agg(distinct cm.member_id) as two
    from public.channel_members cm
    join public.channels c on c.id = cm.channel_id and c.kind = 'dm'
   group by cm.channel_id
  having count(distinct cm.member_id) = 2
),
withn as (
  select p.channel_id, p.two,
         (select count(*) from public.messages m where m.channel_id = p.channel_id) as msgs,
         (select c.created_at from public.channels c where c.id = p.channel_id) as made
    from pair p
),
ranked as (
  select *,
         row_number() over (partition by two order by msgs desc, made asc nulls last) as rn,
         count(*)     over (partition by two) as n
    from withn
)
select * from ranked where n > 1;

do $$
declare
  v_keep uuid; v_dead uuid[]; v_two uuid[];
  v_moved int := 0; v_rooms int := 0;
begin
  for v_two, v_keep, v_dead in
    select two,
           (array_agg(channel_id order by rn))[1],
           (array_agg(channel_id order by rn))[2:]
      from public.v_dm_dupes group by two
  loop
    update public.messages set channel_id = v_keep where channel_id = any(v_dead);
    get diagnostics v_moved = row_count;
    delete from public.channel_reads where channel_id = any(v_dead);
    insert into public.channel_members (channel_id, member_id)
    select v_keep, u from unnest(v_two) u
     where not exists (select 1 from public.channel_members cm
                        where cm.channel_id = v_keep and cm.member_id = u);
    delete from public.channels where id = any(v_dead);
    v_rooms := v_rooms + coalesce(array_length(v_dead, 1), 0);
  end loop;
  raise notice '겹친 방 % 개를 합쳤습니다', v_rooms;
end $$;

drop view if exists public.v_dm_dupes;

-- 같은 사람이 한 방에 두 줄 들어간 것도 한 줄만 남긴다
delete from public.channel_members a
 using public.channel_members b
 where a.channel_id = b.channel_id
   and a.member_id  = b.member_id
   and a.ctid > b.ctid;

-- ── ② 말 한마디 없는 1:1 방 치우기 ────────────────────────────────
do $$
declare v_n int;
begin
  with dead as (
    delete from public.channels c
     where c.kind = 'dm'
       and not exists (select 1 from public.messages m where m.channel_id = c.id)
    returning 1
  ) select count(*) into v_n from dead;
  raise notice '빈 1:1 방 % 개를 치웠습니다', v_n;
end $$;

-- ── ③ 앞으로는 앱이 알아서 치운다 ─────────────────────────────────
--  지금 규칙은 '교직원만 방을 지울 수 있음' 입니다. 그래서 학생이
--  눌러만 보고 닫은 방을 스스로 치울 수가 없었습니다.
--  '내가 만든, 말 한마디 없는 1:1 방' 만 지울 수 있게 좁게 엽니다.
--  말이 한 줄이라도 있으면 막힙니다 — 대화가 사라질 길은 없습니다.
drop policy if exists channels_delete_own_empty_dm on public.channels;
create policy channels_delete_own_empty_dm on public.channels
  for delete to authenticated
  using (
    kind = 'dm'
    and created_by = auth.uid()
    and not exists (select 1 from public.messages m where m.channel_id = channels.id)
  );

notify pgrst, 'reload schema';

-- ── ④ 남은 것 보기 ────────────────────────────────────────────────
select '빈 단체방(토픽) — 보고 직접 지우세요' as "안내",
       c.name as "방 이름", c.created_at as "만든 때",
       (select count(*) from public.channel_members cm where cm.channel_id = c.id) as "사람"
  from public.channels c
 where coalesce(c.kind,'topic') <> 'dm'
   and not exists (select 1 from public.messages m where m.channel_id = c.id)
 order by c.created_at;

select '✅ 정리 끝' as "결과",
       (select count(*) from public.channels where kind = 'dm')      as "남은 1:1 방",
       (select count(*) from public.channels where coalesce(kind,'topic') <> 'dm') as "단체방";
