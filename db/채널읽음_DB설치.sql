-- =====================================================================
--  안읽음 배지 정확화: 채널별 '마지막 읽은 시각' 저장 (사용자별)
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================
create table if not exists public.channel_reads (
  member_id    uuid not null,
  channel_id   uuid not null,
  last_read_at timestamptz not null default now(),
  primary key (member_id, channel_id)
);
alter table public.channel_reads enable row level security;
drop policy if exists channel_reads_own on public.channel_reads;
create policy channel_reads_own on public.channel_reads for all to authenticated
  using (member_id = auth.uid()) with check (member_id = auth.uid());

NOTIFY pgrst, 'reload schema';
