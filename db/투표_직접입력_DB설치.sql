-- =====================================================================
--  🗳 투표 — 투표하는 사람이 항목을 직접 적어 올리기
--
--  요청 (개선창)
--   "투표 시 항목을 투표자가 직접 적어서 올릴 수 있는 것도 추가해주시면
--    감사하겠습니다! 아이들별로 어느 병원을 가야하는지도 같이 볼 수
--    있으면 좋을 것 같아서요!"
--
--  왜 표를 따로 두나
--   투표 항목은 지금 messages.text 안(JSON)에 들어 있습니다. 거기에
--   더하려면 남의 메시지를 고쳐야 하는데, 그건 막혀 있습니다
--   (db/신고차단_DB설치.sql — 자기 메시지만 고칠 수 있음). 그래서
--   나중에 더한 항목만 따로 담습니다.
--
--  ※ db/투표_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.poll_votes') is null then
    raise exception '먼저 db/투표_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- ── 1. 나중에 더한 항목 ──────────────────────────────────────────
create table if not exists public.poll_options (
  id           uuid primary key default gen_random_uuid(),
  message_id   uuid not null references public.messages(id) on delete cascade,
  label        text not null,
  created_by   uuid not null,
  created_name text,
  created_at   timestamptz not null default now()
);
create index if not exists poll_options_msg_idx on public.poll_options (message_id, created_at);

comment on table public.poll_options is
  '투표를 만든 뒤에 참여자가 더한 항목. 처음 항목은 messages.text 안에 있다.';

-- ── 2. 표가 어느 항목에 갔는지 ───────────────────────────────────
--  처음 항목에 준 표는 option_index 로, 나중에 더한 항목은 option_id 로.
--  한쪽이 비어 있으면 다른 쪽을 본다.
alter table public.poll_votes add column if not exists option_id uuid
  references public.poll_options(id) on delete cascade;

--  option_index 를 비울 수 있게 한다 (더한 항목에 준 표는 번호가 없다)
alter table public.poll_votes alter column option_index drop not null;

--  한 사람이 한 항목에 한 번씩.
--  Postgres 는 NULL 끼리 부딪히지 않으므로 두 색인이 서로 간섭하지 않는다.
alter table public.poll_votes drop constraint if exists poll_votes_message_id_option_index_member_id_key;
create unique index if not exists poll_votes_builtin_uniq
  on public.poll_votes (message_id, option_index, member_id);
create unique index if not exists poll_votes_added_uniq
  on public.poll_votes (message_id, option_id, member_id);

-- ── 3. 누가 더하고 누가 지우나 ───────────────────────────────────
--  보기는 로그인한 사람 모두 (투표 결과와 같은 기준).
--  더하기는 자기 이름으로만. 지우기는 적은 본인, 그리고 교직원.
alter table public.poll_options enable row level security;

drop policy if exists poll_options_select on public.poll_options;
create policy poll_options_select on public.poll_options
  for select to authenticated using (true);

drop policy if exists poll_options_insert on public.poll_options;
create policy poll_options_insert on public.poll_options
  for insert to authenticated with check (created_by = auth.uid());

drop policy if exists poll_options_delete on public.poll_options;
create policy poll_options_delete on public.poll_options
  for delete to authenticated
  using ( created_by = auth.uid() or public.is_staff_member() );

grant select, insert, delete on public.poll_options to authenticated;

-- 실시간 반영 — 이미 들어 있으면 넘어간다
do $$
begin
  alter publication supabase_realtime add table public.poll_options;
exception when duplicate_object then null; when others then null;
end $$;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select indexname as "색인" from pg_indexes
 where schemaname='public' and tablename='poll_votes' order by 1;

-- =====================================================================
--  투표를 만들 때 '참여자도 항목을 더할 수 있게' 를 켜면,
--  투표 카드 아래에 [＋ 항목 추가] 가 생깁니다.
--  더한 항목에는 누가 적었는지 이름이 같이 보입니다.
-- =====================================================================
