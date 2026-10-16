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
