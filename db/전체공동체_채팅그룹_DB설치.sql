-- ═══════════════════════════════════════════════════════════════════
--  채팅 — '모든 공동체' 그룹
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  ⚠️ 헛갈리면 안 되는 자리입니다. 선을 한 번만 긋습니다.
--
--    기본  : 채팅방은 그 공동체 사람만.                    ← 지금 그대로
--    예외  : **깃발이 선 그룹 안의 방만** 모든 공동체 사람 중에 초대.
--
--  깃발은 channel_groups.cross_community 하나뿐이고, **총관리자만** 세웁니다.
--  깃발 없는 그룹은 이 파일을 깔아도 글자 하나 달라지지 않습니다.
--
--  ── 이미 되어 있던 것 (재서 확인했습니다) ───────────────────────
--  초대만 되면 공동체가 달라도 방이 보이고 글이 읽히고 쓰입니다.
--  my_channel_ids() 가 '소속'이 아니라 '초대받았는지'만 보기 때문입니다.
--  그래서 messages_select / messages_insert / channels_select 는
--  손댈 것이 없습니다.
--
--  ── 그래서 모자랐던 것 ─────────────────────────────────────────
--  ① 그룹에 깃발이 없었습니다.
--  ② 다른 공동체 사람의 **이름**이 안 보입니다. members_read_guard 가
--     RESTRICTIVE 로 '내 공동체 아니면 못 읽음' 을 걸어 둡니다.
--     → members 정책은 **건드리지 않습니다.** 대신 함수 두 개로만
--       그 방 사람들의 이름을 돌려줍니다. 그 방 밖에서는 아무것도
--       넓어지지 않습니다.
--  ③ 깃발 선 그룹 안에 방을 만드는 건 총·부총관리자만.
--  ④ (겸사겸사 막는 구멍) chgroups_write 가 공동체를 안 봐서, 어느
--     공동체 관리자든 **남의 공동체 그룹**을 고치고 지울 수 있었습니다.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
--  1. 깃발
-- ─────────────────────────────────────────────────────────────────
alter table public.channel_groups
  add column if not exists cross_community boolean not null default false;

comment on column public.channel_groups.cross_community is
  '켜면 이 그룹 안의 방에는 모든 공동체 사람을 초대할 수 있습니다. 총관리자만 켭니다.';

-- ─────────────────────────────────────────────────────────────────
--  2. 거드는 함수
-- ─────────────────────────────────────────────────────────────────

--  그룹에 깃발이 서 있나
create or replace function public.group_is_cross(p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select g.cross_community from public.channel_groups g
                    where g.id = p_group), false);
$$;

--  이 방이 깃발 선 그룹 안에 있나
create or replace function public.channel_is_cross(p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.channels c
     where c.id = p_channel
       and c.group_id is not null
       and public.group_is_cross(c.group_id));
$$;

--  그 방의 공동체 / 종류
create or replace function public.channel_community_of(p_channel uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select c.community_id from public.channels c where c.id = p_channel;
$$;

create or replace function public.channel_kind_of(p_channel uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(c.kind, 'topic') from public.channels c where c.id = p_channel;
$$;

grant execute on function public.group_is_cross(uuid)        to authenticated;
grant execute on function public.channel_is_cross(uuid)      to authenticated;
grant execute on function public.channel_community_of(uuid)  to authenticated;
grant execute on function public.channel_kind_of(uuid)       to authenticated;

-- ─────────────────────────────────────────────────────────────────
--  3. 깃발은 총관리자만 (RESTRICTIVE — 이름을 따로 둡니다)
-- ─────────────────────────────────────────────────────────────────
drop policy if exists chgroups_cross_super_only on public.channel_groups;
create policy chgroups_cross_super_only on public.channel_groups
  as restrictive for update to authenticated
  using (true)
  with check (
    (select public.is_super_admin())
    or cross_community is not distinct from public.group_is_cross(id)
  );

drop policy if exists chgroups_cross_super_ins on public.channel_groups;
create policy chgroups_cross_super_ins on public.channel_groups
  as restrictive for insert to authenticated
  with check (
    (select public.is_super_admin())
    or coalesce(cross_community, false) = false
  );

-- ─────────────────────────────────────────────────────────────────
--  4. 그룹은 자기 공동체 것만 고친다 (구멍 막기)
--     chgroups_write 가 역할만 보고 공동체를 안 봤습니다.
--     ⚠️ chgroups_write 를 '같은 이름으로' 다시 쓰면 옛 설치 파일을
--        다시 돌릴 때 통째로 덮어써집니다. 그래서 이름을 따로 둡니다.
-- ─────────────────────────────────────────────────────────────────
drop policy if exists chgroups_own_community_ins on public.channel_groups;
create policy chgroups_own_community_ins on public.channel_groups
  as restrictive for insert to authenticated
  with check (
    (select public.is_super_admin())
    or community_id is null
    or community_id = (select public.my_community_id())
  );

drop policy if exists chgroups_own_community_upd on public.channel_groups;
create policy chgroups_own_community_upd on public.channel_groups
  as restrictive for update to authenticated
  using (
    (select public.is_super_admin())
    or community_id is null
    or community_id = (select public.my_community_id())
  )
  with check (
    (select public.is_super_admin())
    or community_id is null
    or community_id = (select public.my_community_id())
  );

drop policy if exists chgroups_own_community_del on public.channel_groups;
create policy chgroups_own_community_del on public.channel_groups
  as restrictive for delete to authenticated
  using (
    (select public.is_super_admin())
    or community_id is null
    or community_id = (select public.my_community_id())
  );

-- ─────────────────────────────────────────────────────────────────
--  5. 깃발 선 그룹 안에 방 만들기 = 총·부총관리자만
-- ─────────────────────────────────────────────────────────────────
drop policy if exists channels_cross_group_ins on public.channels;
create policy channels_cross_group_ins on public.channels
  as restrictive for insert to authenticated
  with check (
    group_id is null
    or not public.group_is_cross(group_id)
    or (select public.is_super_admin() or public.is_vice_admin())
  );

drop policy if exists channels_cross_group_upd on public.channels;
create policy channels_cross_group_upd on public.channels
  as restrictive for update to authenticated
  using (true)
  with check (
    group_id is null
    or not public.group_is_cross(group_id)
    or (select public.is_super_admin() or public.is_vice_admin())
  );

-- ─────────────────────────────────────────────────────────────────
--  6. ★ 선 — 초대는 소속공동체만, 깃발 선 방만 예외
--
--     can_add_channel_member 는 **초대받는 사람의 공동체를 아예 안
--     봤습니다.** 그래서 공동체 관리자가 uuid 만 알면 남의 공동체
--     사람을 자기 방에 넣을 수 있었습니다 (이름을 못 읽으니 앱으로는
--     어려웠지만, 선이 그어져 있지 않았습니다).
--
--     1:1 방과 총관리자는 빼 둡니다 — 지금 되는 것을 깨지 않으려고.
--     (총·부총관리자는 원래 공동체를 넘나들며 채팅합니다)
-- ─────────────────────────────────────────────────────────────────
drop policy if exists channel_members_community_line on public.channel_members;
create policy channel_members_community_line on public.channel_members
  as restrictive for insert to authenticated
  with check (
       (select public.is_super_admin())
    or public.channel_kind_of(channel_id) = 'dm'
    --  기본: 그 방의 공동체 사람만
    or public.member_community_of(member_id) = public.channel_community_of(channel_id)
    --  예외: 깃발 선 그룹 안의 방 — 공동체를 넘나드는 사람이 초대할 때만
    or ( public.channel_is_cross(channel_id)
         and (select public.is_vice_admin()) )
  );

-- ─────────────────────────────────────────────────────────────────
--  7. 이름 — members 정책은 건드리지 않습니다
--
--     ① 그 방에 같이 있는 사람들 (방 안에서 이름·사진을 쓰려고)
--     ② 초대 후보 명단 (방을 만들 때 고르려고)
--     둘 다 '깃발 선 그룹' 일 때만 답합니다.
-- ─────────────────────────────────────────────────────────────────

--  ① 이 방에 같이 있는 사람들. 내가 그 방에 있어야 답합니다.
drop function if exists public.cross_channel_members(uuid);
create or replace function public.cross_channel_members(p_channel uuid)
returns table (id uuid, name text, photo_url text, community_role text,
               community_id uuid, community_name text)
language sql stable security definer set search_path = public as $$
  select m.id, m.name, m.photo_url, m.community_role, m.community_id,
         coalesce(c.name, '')
    from public.channel_members cm
    join public.members m    on m.id = cm.member_id
    left join public.communities c on c.id = m.community_id
   where cm.channel_id = p_channel
     and public.channel_is_cross(p_channel)            -- 깃발 선 방만
     and ( exists (select 1 from public.channel_members me
                    where me.channel_id = p_channel and me.member_id = auth.uid())
           or (select public.is_super_admin() or public.is_vice_admin()) );
$$;

--  ② 초대 후보 — 모든 공동체의 쓰는 사람. 총·부총관리자에게만.
drop function if exists public.cross_invite_candidates(uuid);
create or replace function public.cross_invite_candidates(p_group uuid)
returns table (id uuid, name text, photo_url text, community_role text,
               community_id uuid, community_name text)
language sql stable security definer set search_path = public as $$
  select m.id, m.name, m.photo_url, m.community_role, m.community_id,
         coalesce(c.name, '')
    from public.members m
    left join public.communities c on c.id = m.community_id
   where coalesce(m.status, 'active') not in ('removed','pending')
     and m.community_role <> 'store_bot'
     and public.group_is_cross(p_group)                         -- 깃발 선 그룹만
     and (select public.is_super_admin() or public.is_vice_admin())
   order by coalesce(c.name,''), m.name;
$$;

grant execute on function public.cross_channel_members(uuid)   to authenticated;
grant execute on function public.cross_invite_candidates(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────
--  8. 확인
-- ─────────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from pg_policies
   where schemaname='public'
     and policyname in ('chgroups_cross_super_only','chgroups_cross_super_ins',
                        'chgroups_own_community_ins','chgroups_own_community_upd',
                        'chgroups_own_community_del','channels_cross_group_ins',
                        'channels_cross_group_upd','channel_members_community_line');
  if n <> 8 then raise exception '정책이 8개여야 하는데 %개입니다', n; end if;
  raise notice '정책 8개 · 함수 6개 설치 완료';
end $$;
