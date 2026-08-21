-- =====================================================================
--  채팅 투표(poll) 기능 — 카카오톡/잔디 스타일 투표
--  투표 정의(질문·항목·복수·익명·마감)는 messages.kind='poll' 메시지에 저장되고,
--  개별 표는 아래 poll_votes 테이블에 저장됩니다.
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
create table if not exists public.poll_votes (
  id           uuid primary key default gen_random_uuid(),
  message_id   uuid not null references public.messages(id) on delete cascade,
  option_index int  not null,
  member_id    uuid not null,
  member_name  text,
  created_at   timestamptz not null default now(),
  unique (message_id, option_index, member_id)
);
create index if not exists poll_votes_message_idx on public.poll_votes(message_id);

alter table public.poll_votes enable row level security;

-- 모든 로그인 사용자가 결과를 볼 수 있음
drop policy if exists poll_votes_select on public.poll_votes;
create policy poll_votes_select on public.poll_votes
  for select to authenticated using (true);

-- 자기 표만 등록/삭제 가능
drop policy if exists poll_votes_insert on public.poll_votes;
create policy poll_votes_insert on public.poll_votes
  for insert to authenticated with check (member_id = auth.uid());

drop policy if exists poll_votes_delete on public.poll_votes;
create policy poll_votes_delete on public.poll_votes
  for delete to authenticated using (member_id = auth.uid());

-- 실시간(Realtime) 반영 — 이미 추가돼 있으면 무시
do $$
begin
  alter publication supabase_realtime add table public.poll_votes;
exception
  when duplicate_object then null;
  when others then null;
end $$;

NOTIFY pgrst, 'reload schema';
