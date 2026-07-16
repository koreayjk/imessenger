-- =====================================================================
--  TCS 매점(가계부) — 재고·판매·지출·통계 + 용돈 자동 차감
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
--  공동체별로 매점이 분리되며, 매점 관리 페이지는 공동체별 비밀번호로 접근합니다.
-- =====================================================================

-- ── 1) 매점 설정 (공동체별 비밀번호) ─────────────────────────────────
--  pass_hash 는 edge function(service_role)만 읽고 씁니다. 클라이언트 조회 불가.
create table if not exists public.store_settings (
  community_id uuid primary key references public.communities(id) on delete cascade,
  pass_hash    text,
  store_name   text,
  currency       text default '원',   -- '원' | '$' | '₱'
  bot_member_id  uuid,                 -- 영수증을 보내는 '매점' 발신자(members) id
  updated_at     timestamptz default now()
);
-- 이미 있던 경우 컬럼 보강
alter table public.store_settings add column if not exists currency text default '원';
alter table public.store_settings add column if not exists bot_member_id uuid;
alter table public.store_settings enable row level security;
-- 정책 없음 = authenticated/anon 모두 접근 불가 (service_role 만 가능)

-- ── 2) 상품(재고) ───────────────────────────────────────────────────
create table if not exists public.store_products (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name         text not null,
  category     text,
  price        numeric not null default 0,   -- 판매가
  cost         numeric not null default 0,   -- 원가(선택)
  stock        int     not null default 0,   -- 재고 수량
  barcode      text,
  active       boolean not null default true,
  created_at   timestamptz default now()
);
create index if not exists idx_store_products_comm on public.store_products(community_id, active);

-- ── 3) 판매(영수증 단위) ────────────────────────────────────────────
create table if not exists public.store_sales (
  id                 uuid primary key default gen_random_uuid(),
  community_id       uuid not null references public.communities(id) on delete cascade,
  member_id          uuid references public.members(id) on delete set null,  -- null=현금/비회원
  buyer_name         text,
  total              numeric not null default 0,
  pay_method         text default 'allowance',   -- 'allowance'(용돈차감) | 'cash'(현금)
  note               text,
  allowance_entry_id uuid,        -- 연결된 용돈 지출 id (판매 취소시 함께 삭제)
  operator           text,        -- 판매 처리자(매점 담당) 표시용
  voided             boolean not null default false,
  created_at         timestamptz default now()
);
create index if not exists idx_store_sales_comm   on public.store_sales(community_id, created_at desc);
create index if not exists idx_store_sales_member on public.store_sales(member_id, created_at desc);

-- ── 4) 판매 상세(품목) ──────────────────────────────────────────────
create table if not exists public.store_sale_items (
  id         uuid primary key default gen_random_uuid(),
  sale_id    uuid not null references public.store_sales(id) on delete cascade,
  product_id uuid references public.store_products(id) on delete set null,
  name       text,
  qty        int     not null default 1,
  price      numeric not null default 0
);
create index if not exists idx_store_sale_items_sale on public.store_sale_items(sale_id);

-- ── 5) 지출(물품 매입 등) ───────────────────────────────────────────
create table if not exists public.store_expenses (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  date         date not null,
  category     text,
  memo         text,
  amount       numeric not null default 0,
  created_at   timestamptz default now()
);
create index if not exists idx_store_expenses_comm on public.store_expenses(community_id, date desc);

-- ── 6) RLS: TCS(로그인한 관리자·교사·간사)의 '현황 조회'만 허용 ────────
--  쓰기(판매/재고변경/지출)는 전부 edge function(service_role)로 처리합니다.
--  판매 시 학생 용돈 차감도 edge function 이 담당합니다.
create or replace function public.store_can_read(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role = 'super_admin'
        or (me.community_id = cid and me.community_role in ('community_admin','admin_officer','teacher','staff'))
      )
  );
$$;

alter table public.store_products enable row level security;
drop policy if exists store_products_read on public.store_products;
create policy store_products_read on public.store_products for select to authenticated
  using (public.store_can_read(community_id));

alter table public.store_sales enable row level security;
drop policy if exists store_sales_read on public.store_sales;
create policy store_sales_read on public.store_sales for select to authenticated
  using (public.store_can_read(community_id));

alter table public.store_sale_items enable row level security;
drop policy if exists store_sale_items_read on public.store_sale_items;
create policy store_sale_items_read on public.store_sale_items for select to authenticated
  using (exists (select 1 from public.store_sales s where s.id = store_sale_items.sale_id and public.store_can_read(s.community_id)));

alter table public.store_expenses enable row level security;
drop policy if exists store_expenses_read on public.store_expenses;
create policy store_expenses_read on public.store_expenses for select to authenticated
  using (public.store_can_read(community_id));

NOTIFY pgrst, 'reload schema';
