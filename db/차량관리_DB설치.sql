-- =====================================================================
--  🚗 차량관리 (학사관리 → 차량)
--   · vehicles       차량 목록
--   · vehicle_logs   정비·지출 이력
--  Supabase → SQL Editor 에 통째로 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================

create table if not exists public.vehicles (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  plate         text not null,          -- 번호판
  name          text,                   -- 별칭 (예: 스타리아)
  make          text,                   -- 제조사
  model         text,
  year          int,
  vin           text,
  color         text,
  odometer      int,                    -- 최근 주행거리 (mi)
  odometer_at   date,                   -- 그 주행거리를 적은 날
  insurance_exp    date,                -- 보험 만료
  registration_exp date,                -- 등록(Registration) 만료
  inspection_exp   date,                -- 정기검사 만료
  intervals     jsonb,                  -- 차량별 정비 주기 덮어쓰기 {"oil":{"mi":5000,"mo":6}}
  photo_url     text,
  note          text,
  active        boolean default true,
  sort          int default 0,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create table if not exists public.vehicle_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  vehicle_id    uuid not null references public.vehicles(id) on delete cascade,
  kind          text not null,          -- oil / air_filter / tire / battery ...
  title         text,
  service_date  date not null,
  odometer      int,
  cost          numeric(12,2),
  vendor        text,                   -- 정비소
  warranty_until date,
  note          text,
  created_at    timestamptz default now(),
  created_by    uuid
);

create unique index if not exists vehicles_comm_plate_uidx on public.vehicles (community_id, plate);
create index if not exists vehicle_logs_v_idx on public.vehicle_logs (vehicle_id, service_date desc);
create index if not exists vehicle_logs_comm_idx on public.vehicle_logs (community_id, service_date desc);

-- RLS — 로그인 사용자 접근 허용 (다른 학사 테이블과 같은 방식)
alter table public.vehicles     enable row level security;
alter table public.vehicle_logs enable row level security;
drop policy if exists vehicles_rw on public.vehicles;
create policy vehicles_rw on public.vehicles for all to authenticated using (true) with check (true);
drop policy if exists vehicle_logs_rw on public.vehicle_logs;
create policy vehicle_logs_rw on public.vehicle_logs for all to authenticated using (true) with check (true);

-- =====================================================================
--  지금까지 기록해 온 내역 (IM America Task Tracker 시트)
--  community_id 가 다르면 아래 cid 값만 바꿔서 실행하세요.
-- =====================================================================
do $$
declare
  cid uuid := '00000000-0000-0000-0000-000000000001';
  v_id uuid;
begin

  -- ── TKM3660 ──
  insert into public.vehicles (community_id, plate, make, model, year, odometer, odometer_at, note, sort)
  values (cid, 'TKM3660', 'Honda', '', 2019, 193607, '2026-05-08', '인수 시점 주행거리 126,323 mi (2023-10-28)', 0)
  on conflict (community_id, plate) do update
     set make = excluded.make, model = excluded.model, year = excluded.year,
         odometer = coalesce(public.vehicles.odometer, excluded.odometer),
         odometer_at = coalesce(public.vehicles.odometer_at, excluded.odometer_at),
         note = coalesce(public.vehicles.note, excluded.note)
  returning id into v_id;

  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2025-12-12', 185768, 96.1, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2025-12-12' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2026-05-08', 193607, 66.88, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2026-05-08' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터', '2023-12-30', null, 29.99, null, '원본 시트: Air / Cabin — $29.99 / $49.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2023-12-30' and coalesce(title,'') = '에어필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2023-12-30', null, 49.99, null, '원본 시트: Air / Cabin — $29.99 / $49.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2023-12-30' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2024-04-07', null, 49.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2024-04-07' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터', '2024-12-18', null, 33.99, null, '원본 시트: Air / Cabin — $33.99 / $49.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2024-12-18' and coalesce(title,'') = '에어필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2024-12-18', null, 49.99, null, '원본 시트: Air / Cabin — $33.99 / $49.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2024-12-18' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'trans', '미션오일 교환', '2024-12-30', null, 205.0, null, '원본 시트: Mission Fluid Change — $130+$75'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'trans' and service_date = '2024-12-30' and coalesce(title,'') = '미션오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터', '2026-02-03', null, null, null, '원본 시트: Air / Cabin — 금액 미기재'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2026-02-03' and coalesce(title,'') = '에어필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2026-02-03', null, null, null, '원본 시트: Air / Cabin — 금액 미기재'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2026-02-03' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '타이어 4개 교체 (235/60R18)', '2023-11-19', null, 907.96, null, '원본 시트: each $206.99 + $80 → 4개 기준으로 합산'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2023-11-19' and coalesce(title,'') = '타이어 4개 교체 (235/60R18)');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'battery', '배터리 교체', '2024-06-24', null, 219.48, '2026-06-24', '2년 워런티'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'battery' and service_date = '2024-06-24' and coalesce(title,'') = '배터리 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'brake', '앞 브레이크 패드 + 뒤 로터', '2025-01-18', null, 182.7, null, '원본 시트: Front Pad+Rour'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'brake' and service_date = '2025-01-18' and coalesce(title,'') = '앞 브레이크 패드 + 뒤 로터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '타이어 2개 교체 (뒤 신품 / 앞 기존)', '2025-04-22', null, 453.98, null, '원본 시트: each $206.99 + $40 → 2개 기준으로 합산'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2025-04-22' and coalesce(title,'') = '타이어 2개 교체 (뒤 신품 / 앞 기존)');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '타이어 2개 교체 (뒤 기존 / 앞 신품)', '2025-11-17', null, 260.0, null, '원본 시트: each $100 + $60 → 2개 기준으로 합산'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2025-11-17' and coalesce(title,'') = '타이어 2개 교체 (뒤 기존 / 앞 신품)');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'battery', '배터리 교체 (워런티 무상)', '2026-02-19', null, 0.0, null, '2026-06-24 까지 워런티가 남아 무상 교체'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'battery' and service_date = '2026-02-19' and coalesce(title,'') = '배터리 교체 (워런티 무상)');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'wiper', '와이퍼 교체', '2023-12-15', null, 20.0, null, '원본 시트: each $10 → 2개 기준으로 합산'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'wiper' and service_date = '2023-12-15' and coalesce(title,'') = '와이퍼 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'coolant', '냉각수 교환', '2024-04-07', null, 140.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'coolant' and service_date = '2024-04-07' and coalesce(title,'') = '냉각수 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'coolant', '냉각수 교환', '2025-04-24', null, 163.0, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'coolant' and service_date = '2025-04-24' and coalesce(title,'') = '냉각수 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'timing', '타이밍벨트 키트 + ECM', '2026-02-01', null, 1324.0, null, '원본 시트: $140 + $1,184'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'timing' and service_date = '2026-02-01' and coalesce(title,'') = '타이밍벨트 키트 + ECM');

  -- ── TYB2101 ──
  insert into public.vehicles (community_id, plate, make, model, year, odometer, odometer_at, note, sort)
  values (cid, 'TYB2101', 'Ford', '', 2015, 178821, '2026-06-24', '인수 시점 주행거리 158,037 mi (2024-03-12)', 1)
  on conflict (community_id, plate) do update
     set make = excluded.make, model = excluded.model, year = excluded.year,
         odometer = coalesce(public.vehicles.odometer, excluded.odometer),
         odometer_at = coalesce(public.vehicles.odometer_at, excluded.odometer_at),
         note = coalesce(public.vehicles.note, excluded.note)
  returning id into v_id;

  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2024-08-29', 165050, 84.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2024-08-29' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2025-09-29', 176416, 101.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2025-09-29' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2026-06-24', 178821, 116.04, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2026-06-24' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터', '2024-08-28', null, 26.99, null, '원본 시트: Air / Cabin — $26.99 / $23.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2024-08-28' and coalesce(title,'') = '에어필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2024-08-28', null, 23.99, null, '원본 시트: Air / Cabin — $26.99 / $23.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2024-08-28' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'coolant', '냉각수 교환', '2024-08-29', null, 140.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'coolant' and service_date = '2024-08-29' and coalesce(title,'') = '냉각수 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터', '2025-09-29', null, 34.99, null, '원본 시트: Air / Cabin — $34.99 / $48.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2025-09-29' and coalesce(title,'') = '에어필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2025-09-29', null, 48.99, null, '원본 시트: Air / Cabin — $34.99 / $48.99'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2025-09-29' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '타이어 펑크 패치 · 밸브 스템', '2024-07-10', null, 15.0, null, '원본 시트: RR_Patches, Stems — each $15 (수량 미상)'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2024-07-10' and coalesce(title,'') = '타이어 펑크 패치 · 밸브 스템');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'brake', '뒤 브레이크 패드', '2024-08-08', null, 700.0, null, '원본 시트: Break Pads back'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'brake' and service_date = '2024-08-08' and coalesce(title,'') = '뒤 브레이크 패드');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'repair', '스타터 교체', '2025-01-22', null, 285.0, null, '원본 시트: Replace Starter — $160 + $125'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'repair' and service_date = '2025-01-22' and coalesce(title,'') = '스타터 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'battery', '배터리 교체', '2026-01-19', null, null, '2028-01-19', '2년 워런티 · 금액 미기재'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'battery' and service_date = '2026-01-19' and coalesce(title,'') = '배터리 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'wiper', '와이퍼 교체', '2024-03-04', null, 63.98, null, '원본 시트: each $31.99 → 2개 기준으로 합산'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'wiper' and service_date = '2024-03-04' and coalesce(title,'') = '와이퍼 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'repair', '디퍼렌셜 링기어', '2024-08-22', null, 4444.99, null, '원본 시트: Differential Ring ~'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'repair' and service_date = '2024-08-22' and coalesce(title,'') = '디퍼렌셜 링기어');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'repair', '앞유리 교체', '2024-05-23', null, 235.31, null, '원본 시트: Front Windshield Rep'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'repair' and service_date = '2024-05-23' and coalesce(title,'') = '앞유리 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'repair', '뒷유리 교체', '2024-11-18', null, 287.79, null, '원본 시트: Back Windshield Rep'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'repair' and service_date = '2024-11-18' and coalesce(title,'') = '뒷유리 교체');

  -- ── VRC0595 ──
  insert into public.vehicles (community_id, plate, make, model, year, odometer, odometer_at, note, sort)
  values (cid, 'VRC0595', 'Ford', '', 2021, 106240, '2026-06-19', '인수 시점 주행거리 64,676 mi (2024-08-31)', 2)
  on conflict (community_id, plate) do update
     set make = excluded.make, model = excluded.model, year = excluded.year,
         odometer = coalesce(public.vehicles.odometer, excluded.odometer),
         odometer_at = coalesce(public.vehicles.odometer_at, excluded.odometer_at),
         note = coalesce(public.vehicles.note, excluded.note)
  returning id into v_id;

  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2025-03-05', 76196, 101.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2025-03-05' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2025-07-07', 79196, 122.66, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2025-07-07' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2025-12-25', 90000, null, null, '원본 시트에 금액 미기재'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2025-12-25' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2026-06-19', 106240, 127.93, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2026-06-19' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'air_filter', '에어필터 · 캐빈필터', '2026-06-19', null, 25.0, null, '원본 시트: Air / Cabin — $25 (합산 금액)'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'air_filter' and service_date = '2026-06-19' and coalesce(title,'') = '에어필터 · 캐빈필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'cabin_filter', '캐빈(에어컨)필터', '2026-06-19', null, null, null, '에어필터와 함께 교환 — 금액은 에어필터 기록에 포함'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'cabin_filter' and service_date = '2026-06-19' and coalesce(title,'') = '캐빈(에어컨)필터');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '뒷 타이어 신품', '2024-10-30', null, 186.88, null, '원본 시트: RR_New Tire'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2024-10-30' and coalesce(title,'') = '뒷 타이어 신품');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'tire', '타이어 4개 교체', '2025-09-27', null, 800.0, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'tire' and service_date = '2025-09-27' and coalesce(title,'') = '타이어 4개 교체');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'coolant', '냉각수 교환', '2025-03-05', null, 140.99, null, null
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'coolant' and service_date = '2025-03-05' and coalesce(title,'') = '냉각수 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'ac', '에어컨 가스 충전', '2025-08-28', null, 162.38, null, '원본 시트: A/C Recharge'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'ac' and service_date = '2025-08-28' and coalesce(title,'') = '에어컨 가스 충전');

  -- ── XGX5676 ──
  insert into public.vehicles (community_id, plate, make, model, year, odometer, odometer_at, note, sort)
  values (cid, 'XGX5676', 'Toyota', 'Sienna', 2008, null, null, '주행거리 기준일 2025-10-03 (원본 시트에 숫자 없음)', 3)
  on conflict (community_id, plate) do update
     set make = excluded.make, model = excluded.model, year = excluded.year,
         odometer = coalesce(public.vehicles.odometer, excluded.odometer),
         odometer_at = coalesce(public.vehicles.odometer_at, excluded.odometer_at),
         note = coalesce(public.vehicles.note, excluded.note)
  returning id into v_id;

  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'oil', '엔진오일 교환', '2026-02-19', null, null, null, '원본 시트에 주행거리·금액 미기재'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'oil' and service_date = '2026-02-19' and coalesce(title,'') = '엔진오일 교환');
  insert into public.vehicle_logs (community_id, vehicle_id, kind, title, service_date, odometer, cost, warranty_until, note)
  select cid, v_id, 'ac', '에어컨 가스 충전', '2025-09-27', null, 165.25, null, '원본 시트: A/C Gas Refill'
  where not exists (select 1 from public.vehicle_logs
                    where vehicle_id = v_id and kind = 'ac' and service_date = '2025-09-27' and coalesce(title,'') = '에어컨 가스 충전');

end $$;

-- ── 확인 ──
select v.plate, v.make, v.year, v.odometer, count(l.id) as 기록수, sum(l.cost) as 총지출
from public.vehicles v left join public.vehicle_logs l on l.vehicle_id = v.id
group by v.id, v.plate, v.make, v.year, v.odometer
order by v.sort;
