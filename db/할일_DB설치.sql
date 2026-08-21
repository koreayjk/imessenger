-- =====================================================================
--  채팅방 할 일(To-Do) 기능 — 잔디 메신저 스타일 협업 태스크
--  채널별 할 일 목록: 담당자·마감일·완료 체크. 실시간 반영.
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
create table if not exists public.todos (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null,
  channel_id      uuid not null,
  title           text not null,
  assigned_to     uuid,
  assigned_name   text,
  due_date        date,
  completed       boolean not null default false,
  created_by      uuid,
  created_by_name text,
  created_at      timestamptz not null default now()
);
create index if not exists todos_channel_idx on public.todos(channel_id);

alter table public.todos enable row level security;

-- 로그인한 사용자는 모두 조회 가능
drop policy if exists todos_select on public.todos;
create policy todos_select on public.todos
  for select to authenticated using (true);

-- 추가: 본인이 만든 것으로만 등록
drop policy if exists todos_insert on public.todos;
create policy todos_insert on public.todos
  for insert to authenticated with check (auth.uid() = created_by or created_by is null);

-- 완료 체크: 채널 구성원 누구나 (협업)
drop policy if exists todos_update on public.todos;
create policy todos_update on public.todos
  for update to authenticated using (true) with check (true);

-- 삭제: 작성자 또는 총관리자(koreayjk)만
drop policy if exists todos_delete on public.todos;
create policy todos_delete on public.todos
  for delete to authenticated
  using (auth.uid() = created_by or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com');

-- 실시간(Realtime) 반영 — 이미 추가돼 있으면 무시
do $$
begin
  alter publication supabase_realtime add table public.todos;
exception
  when duplicate_object then null;
  when others then null;
end $$;

NOTIFY pgrst, 'reload schema';
