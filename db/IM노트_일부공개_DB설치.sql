-- ═══════════════════════════════════════════════════════════════
--  IM노트 — 일부 공개 (고른 사람 · 고른 반에게만)
--
--  지금은 '나만 보기' 와 '공동체 전체' 둘뿐입니다. 여기에 세 번째를 넣습니다.
--      visibility = 'selected'  → share_members / share_groups 에 든 사람만
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 [Run] 한 번이면 끝납니다.
--  여러 번 실행해도 안전하고, 이미 있는 노트는 건드리지 않습니다.
--  ※ db/IM노트_DB설치.sql 을 먼저 실행해 두셔야 합니다.
-- ═══════════════════════════════════════════════════════════════

alter table public.notes add column if not exists share_members uuid[] not null default '{}';
alter table public.notes add column if not exists share_groups  uuid[] not null default '{}';

comment on column public.notes.share_members is 'visibility=selected 일 때 볼 수 있는 멤버 id';
comment on column public.notes.share_groups  is 'visibility=selected 일 때 볼 수 있는 반(student_groups) id';

-- 배열 안을 찾는 조회라 GIN 색인이 있어야 빠르다
create index if not exists notes_share_members_idx on public.notes using gin (share_members);
create index if not exists notes_share_groups_idx  on public.notes using gin (share_groups);

-- 내가 속한 반. security definer 라 notes 정책 안에서 members 를 읽어도
-- RLS 가 다시 돌지 않는다(재귀 방지). stable 이라 한 질의에서 한 번만 계산된다.
create or replace function public.my_group_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select group_id from public.members where id = auth.uid();
$$;

revoke all on function public.my_group_id() from public, anon;
grant execute on function public.my_group_id() to authenticated;

-- 조회 정책 — 기존 두 가지 + '고른 사람만'
drop policy if exists notes_select on public.notes;
create policy notes_select on public.notes
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'community' and community_id = public.my_community_id())
    or (
      visibility = 'selected'
      and community_id = public.my_community_id()
      and (
        auth.uid() = any (share_members)
        or (public.my_group_id() is not null and public.my_group_id() = any (share_groups))
      )
    )
  );

-- 쓰기는 그대로 본인 노트만. (남이 내 노트를 고쳐 공개 범위를 넓히면 안 된다)
drop policy if exists notes_update on public.notes;
create policy notes_update on public.notes
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

NOTIFY pgrst, 'reload schema';

-- ── 확인 ──
-- 아래가 2줄 나오면 설치 완료입니다.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'notes'
  and column_name in ('share_members','share_groups')
order by column_name;
