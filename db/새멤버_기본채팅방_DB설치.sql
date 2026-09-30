-- =====================================================================
--  💬 새 멤버 기본 채팅방
--
--  무엇이 문제였나
--   승인할 때 채팅방에 자동으로 넣는 기능은 원래 있었습니다.
--   다만 '고정(📌)된 채널'만 대상이었는데, 고정 채널이 하나도 없는 공동체에서는
--   조용히 아무 일도 안 일어났습니다. (IM HQ: 채널 5개, 고정 0개)
--   게다가 총관리자가 '공동체별 멤버' 화면에서 승인하는 경로에는
--   자동 참여가 아예 빠져 있었습니다.
--   그래서 승인된 사람이 로그인은 되는데 채팅이 텅 비어 있고,
--   본인은 "계정이 사라졌다"고 느낍니다. 실제로 12명에게 일어났습니다.
--
--  이 컬럼
--   공동체마다 '새로 승인된 사람이 자동으로 들어갈 채팅방'을 정해 둡니다.
--   비워 두면 예전처럼 고정(📌) 채널을 씁니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.communities
  add column if not exists welcome_channel_ids uuid[] not null default '{}';

comment on column public.communities.welcome_channel_ids is
  '새로 승인된 멤버가 자동으로 들어갈 채팅방 id 목록. 비어 있으면 고정(pinned) 채널을 쓴다.';

-- 이미 고정 채널을 쓰고 있던 공동체는 그 값을 그대로 옮겨 둔다.
-- (지금과 똑같이 동작하되, 설정 화면에서 눈에 보이게 된다)
update public.communities c
   set welcome_channel_ids = sub.ids
  from (
    select community_id, array_agg(id) as ids
      from public.channels
     where pinned is true and coalesce(kind,'') <> 'dm'
     group by community_id
  ) sub
 where sub.community_id = c.id
   and coalesce(array_length(c.welcome_channel_ids, 1), 0) = 0;

notify pgrst, 'reload schema';

-- ── 확인 ──
select c.name                                        as "공동체",
       coalesce(array_length(c.welcome_channel_ids,1), 0) as "기본 채팅방 수",
       (select count(*) from public.channels ch
         where ch.community_id = c.id and coalesce(ch.kind,'') <> 'dm') as "전체 채널"
  from public.communities c
 order by c.name;

-- =====================================================================
--  이제 관리자 → 공동체 설정 에서 채팅방을 골라 두면,
--  승인하는 순간 자동으로 들어갑니다.
--  이미 승인됐는데 방이 없는 사람들은 같은 화면의
--  '채팅방 없는 멤버 한 번에 넣기' 로 한 번에 처리할 수 있습니다.
-- =====================================================================
