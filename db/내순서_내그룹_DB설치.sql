-- ════════════════════════════════════════════════════════════════════
--  🗂 채팅 순서와 그룹을 사람마다 따로
--
--  "모든 사람이 자신의 채팅과 토픽 순서를 바꾸고 본인만의 그룹으로
--   묶을 수 있도록 해줘. 나는 되는데 이게 학생은 안 되나?"
--
--  안 됐습니다. 두 가지가 막고 있었습니다.
--    1. 순서 바꾸기가 관리자 전용이었습니다 (canReorderChannels).
--    2. 순서와 그룹을 channels.sort / channels.group_id 에 적고
--       있었습니다. 그건 공동체가 같이 쓰는 줄이라, 한 사람이 옮기면
--       그 방을 보는 모두의 순서가 바뀝니다. '본인만의 그룹' 이
--       아니었습니다.
--
--  개인 덧층을 둡니다. 공동체 기본값(channels.sort/group_id)은 그대로
--  두고, 내가 옮긴 것만 위에 얹습니다. 한 번도 안 옮긴 사람은 예전과
--  똑같이 보입니다.
--
--  두 번 돌려도 안전합니다.
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

select '설치 끝 — 이제 각자 순서를 바꾸고 자기 그룹을 만들 수 있어요' as "결과";
