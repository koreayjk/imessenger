-- =====================================================================
--  채팅: 토픽 그룹 + 1:1 즐겨찾기 + 최신순 정렬
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================

-- 토픽 그룹
create table if not exists public.channel_groups (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid,
  name          text,
  sort          int,
  created_at    timestamptz default now()
);

-- 채널: 그룹 소속 + 마지막 메시지 시각(1:1 최신순)
alter table public.channels add column if not exists group_id uuid;
alter table public.channels add column if not exists last_message_at timestamptz;

-- 채널 멤버: 1:1 즐겨찾기(사용자별)
alter table public.channel_members add column if not exists favorite boolean default false;

-- 기존 채널 last_message_at 백필
update public.channels c
   set last_message_at = m.mx
  from (select channel_id, max(created_at) mx from public.messages group by channel_id) m
 where m.channel_id = c.id and c.last_message_at is null;

-- RLS: 그룹은 로그인 사용자 조회, 관리자만 생성/수정/삭제
alter table public.channel_groups enable row level security;
drop policy if exists chgroups_select on public.channel_groups;
drop policy if exists chgroups_write  on public.channel_groups;
create policy chgroups_select on public.channel_groups for select to authenticated using (true);
create policy chgroups_write on public.channel_groups for all to authenticated
  using (exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin')))
  with check (exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin')));

NOTIFY pgrst, 'reload schema';
