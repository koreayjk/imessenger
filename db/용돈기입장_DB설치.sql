-- =====================================================================
--  용돈기입장 — 학생 본인 용돈 관리 (통화 선택 + 삭제 승인 절차)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (신규 설치 / 업그레이드 겸용)
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
  currency      text not null default '원',   -- '원' | '$'
  delete_status text,                          -- null(정상) | 'requested'(삭제요청)
  delete_requested_at timestamptz,
  created_at    timestamptz default now()
);

-- 이미 테이블이 있던 경우 컬럼 보강
alter table public.allowance_entries add column if not exists currency text not null default '원';
alter table public.allowance_entries add column if not exists delete_status text;
alter table public.allowance_entries add column if not exists delete_requested_at timestamptz;

create index if not exists idx_allowance_member_date on public.allowance_entries (member_id, date desc);

-- =====================================================================
--  RLS
--  - 조회/수정: 본인 + 담당교사 + 관리자
--  - 추가: 본인 + 담당교사 + 관리자 (선생님이 학생 지출을 대신 기록 가능)
--  - 삭제(=요청 승인): 담당교사·관리자만 (학생 본인은 직접 삭제 불가 → '요청'만)
-- =====================================================================
alter table public.allowance_entries enable row level security;

drop policy if exists allowance_own    on public.allowance_entries;
drop policy if exists allowance_select on public.allowance_entries;
drop policy if exists allowance_insert on public.allowance_entries;
drop policy if exists allowance_update on public.allowance_entries;
drop policy if exists allowance_delete on public.allowance_entries;

create policy allowance_select on public.allowance_entries for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

create policy allowance_insert on public.allowance_entries for insert to authenticated
with check (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

create policy allowance_update on public.allowance_entries for update to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

create policy allowance_delete on public.allowance_entries for delete to authenticated
using (
  exists (select 1 from public.members s where s.id = allowance_entries.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);

NOTIFY pgrst, 'reload schema';
