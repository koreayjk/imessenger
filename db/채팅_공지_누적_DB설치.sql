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
