-- =====================================================================
--  용돈기입장 — 학생 본인 용돈 관리 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.allowance_entries (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  date          date not null,
  type          text not null,            -- 'income'(수입) | 'expense'(지출)
  category      text,
  memo          text,
  amount        numeric not null default 0,
  created_at    timestamptz default now()
);

create index if not exists idx_allowance_member_date
  on public.allowance_entries (member_id, date desc);

-- =====================================================================
--  RLS — 본인 기록만 보고/쓰기 (다른 사람 용돈은 볼 수 없음)
-- =====================================================================
alter table public.allowance_entries enable row level security;

drop policy if exists allowance_own on public.allowance_entries;
create policy allowance_own on public.allowance_entries
  for all
  to authenticated
  using (member_id = auth.uid())
  with check (member_id = auth.uid());

-- 실시간(선택): 여러 기기에서 즉시 반영하려면 아래도 실행
-- alter publication supabase_realtime add table public.allowance_entries;
