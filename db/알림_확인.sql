-- =====================================================================
--  🔎 알림이 누구에게 가는지 보는 조회 (읽기만 합니다 · 아무것도 안 고칩니다)
--
--  "이 채팅방에 알림이 돼?" 를 추측하지 않고 직접 봅니다.
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요.
--
--  ↓ 보고 싶은 채팅방 이름을 여기 적으세요 (일부만 적어도 됩니다)
-- =====================================================================
\set ON_ERROR_STOP off

with target as (
  select id, name, kind, community_id
    from public.channels
   where name ilike '%' || 'IM뉴스룸' || '%'      -- ← 여기를 바꾸세요
)

-- ① 이 방에 알림이 갈 사람 / 안 갈 사람
select
  c.name                                   as "채팅방",
  count(*)                                 as "방 사람",
  count(*) filter (where ps.id is not null)            as "알림 켠 기기 있음",
  count(*) filter (where ps.id is null)                as "알림 켠 적 없음",
  count(*) filter (where ps.kind = 'web')              as "브라우저",
  count(*) filter (where ps.kind = 'ios')              as "아이폰 앱",
  count(*) filter (where ps.enabled is false)          as "껐음",
  count(*) filter (where position(c.id::text in coalesce(ps.mutes,'')) > 0) as "이 방만 껐음"
from target c
join public.channel_members cm on cm.channel_id = c.id
left join public.push_subscriptions ps on ps.member_id = cm.member_id
group by c.name
order by c.name;

-- ② 누가 못 받는지 이름으로 (알림을 한 번도 안 켠 사람)
select
  c.name  as "채팅방",
  m.name  as "알림 안 켠 사람",
  m.community_role as "역할"
from target c
join public.channel_members cm on cm.channel_id = c.id
join public.members m on m.id = cm.member_id
where m.status <> 'removed'
  and not exists (select 1 from public.push_subscriptions ps where ps.member_id = m.id)
order by c.name, m.name;

-- ③ ⚠️ 방을 볼 수는 있는데 '방 사람' 줄이 없는 사람
--    총관리자처럼 모든 방이 보이는 사람은 channel_members 줄이 없을 수
--    있습니다. 알림은 이 줄을 보고 보내므로, 줄이 없으면 안 갑니다.
select
  c.name as "채팅방",
  m.name as "방 사람 줄이 없어 알림이 안 가는 사람",
  m.community_role as "역할"
from target c
join public.members m on m.community_id = c.community_id
where m.status = 'active'
  and m.community_role in ('super_admin','vice_admin','community_admin')
  and not exists (select 1 from public.channel_members cm
                   where cm.channel_id = c.id and cm.member_id = m.id)
order by c.name, m.name;

-- ④ 전체 현황 — 우리 공동체에서 알림을 켠 기기
select
  coalesce(kind,'web') as "길",
  count(*)             as "기기 수",
  count(*) filter (where enabled)     as "켜짐",
  max(last_ok_at)      as "마지막으로 잘 간 때"
from public.push_subscriptions
group by 1 order by 1;
