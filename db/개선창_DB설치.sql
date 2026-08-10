-- =====================================================================
--  개선 제안 게시판 (개선창) — 모든 공동체 사용자가 함께 보는 전역 게시판
--  누구나 개선 아이디어를 올리고, 총관리자가 상태(진행예정/이미있음/구현완료/불가능)와 코멘트를 남김
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================

create table if not exists public.improvements (
  id             uuid primary key default gen_random_uuid(),
  author_id      uuid references public.members(id) on delete set null,
  author_name    text,
  community_name text,
  title          text,
  content        text,
  status         text not null default 'pending',  -- pending|planned|exists|done|rejected
  admin_note     text,
  created_at     timestamptz default now()
);
create index if not exists idx_improvements_created on public.improvements (created_at desc);

create table if not exists public.improvement_comments (
  id              uuid primary key default gen_random_uuid(),
  improvement_id  uuid not null references public.improvements(id) on delete cascade,
  author_id       uuid references public.members(id) on delete set null,
  author_name     text,
  is_admin        boolean default false,
  content         text,
  created_at      timestamptz default now()
);
create index if not exists idx_improvement_comments on public.improvement_comments (improvement_id, created_at);

-- 관리자(상태 변경 권한) 판별: community_role super_admin 또는 총관리자 이메일
create or replace function public.is_improve_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members where id = auth.uid() and community_role = 'super_admin')
      or coalesce(auth.jwt() ->> 'email', '') = 'koreayjk@gmail.com';
$$;

alter table public.improvements enable row level security;
alter table public.improvement_comments enable row level security;

-- 개선 제안: 모두 조회 / 본인 작성 / 상태변경(수정)은 관리자 / 삭제는 본인·관리자
drop policy if exists improvements_select on public.improvements;
drop policy if exists improvements_insert on public.improvements;
drop policy if exists improvements_update on public.improvements;
drop policy if exists improvements_delete on public.improvements;
create policy improvements_select on public.improvements for select to authenticated using (true);
create policy improvements_insert on public.improvements for insert to authenticated with check (author_id = auth.uid());
create policy improvements_update on public.improvements for update to authenticated using (public.is_improve_admin()) with check (public.is_improve_admin());
create policy improvements_delete on public.improvements for delete to authenticated using (author_id = auth.uid() or public.is_improve_admin());

-- 코멘트: 모두 조회 / 본인 작성 / 삭제는 본인·관리자
drop policy if exists impcomments_select on public.improvement_comments;
drop policy if exists impcomments_insert on public.improvement_comments;
drop policy if exists impcomments_delete on public.improvement_comments;
create policy impcomments_select on public.improvement_comments for select to authenticated using (true);
create policy impcomments_insert on public.improvement_comments for insert to authenticated with check (author_id = auth.uid());
create policy impcomments_delete on public.improvement_comments for delete to authenticated using (author_id = auth.uid() or public.is_improve_admin());

NOTIFY pgrst, 'reload schema';
