-- =====================================================================
--  재정 · 입출금(거래내역) 관리 — 은행 엑셀 업로드 + 자동분류 + 월별 관리
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- 교직원(재정 담당) 판별 헬퍼 — 이미 있으면 갱신
create or replace function public.is_finance_staff()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff')
        or me.role in ('총관리자','관리자','행정담당자','교사','간사')
      )
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

create table if not exists public.finance_transactions (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null,
  tx_date         date,
  month           text,                 -- 'YYYY-MM'
  description     text,
  amount          numeric not null default 0,   -- 부호: (+)입금/수입, (-)출금/지출
  category        text,
  notes           text,
  source          text default 'manual', -- 'manual' | 'import'
  created_by      uuid,
  created_by_name text,
  created_at      timestamptz not null default now()
);
create index if not exists fin_tx_comm_month_idx on public.finance_transactions(community_id, month);
create index if not exists fin_tx_date_idx on public.finance_transactions(tx_date);

alter table public.finance_transactions enable row level security;

drop policy if exists fin_tx_select on public.finance_transactions;
create policy fin_tx_select on public.finance_transactions
  for select to authenticated using (public.is_finance_staff());

drop policy if exists fin_tx_insert on public.finance_transactions;
create policy fin_tx_insert on public.finance_transactions
  for insert to authenticated with check (public.is_finance_staff());

drop policy if exists fin_tx_update on public.finance_transactions;
create policy fin_tx_update on public.finance_transactions
  for update to authenticated using (public.is_finance_staff()) with check (public.is_finance_staff());

drop policy if exists fin_tx_delete on public.finance_transactions;
create policy fin_tx_delete on public.finance_transactions
  for delete to authenticated using (public.is_finance_staff());

NOTIFY pgrst, 'reload schema';
