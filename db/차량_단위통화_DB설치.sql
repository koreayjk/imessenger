-- =====================================================================
--  🚗 차량 — km/원 단위 선택 · 명의 · 보험사
--
--  1) 공동체마다 거리 단위(mi|km)와 통화를 고를 수 있게 합니다.
--     거리는 **늘 마일로 저장**하고 보여줄 때만 바꿉니다. 표시만
--     'km' 로 갈아끼우면 이미 들어 있는 숫자가 전부 틀어집니다.
--  2) 돈은 바꿔 계산하지 않습니다 — 환율은 날마다 달라서, 예전에 $로
--     적은 40 을 오늘 환율로 원으로 고치는 건 거짓이 됩니다. 그래서
--     **정비 기록마다 그때의 통화**를 같이 적어 두고, 합계는 통화별로
--     따로 냅니다. 예전 기록은 '$' 로 봅니다 (그때 그렇게 적었으니까).
--  3) 차량에 명의(owner_name)와 보험사(insurer) 칸을 더합니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.communities
  add column if not exists veh_unit     text default 'mi',
  add column if not exists veh_currency text default '$';

alter table public.vehicles
  add column if not exists owner_name text,
  add column if not exists insurer    text;

alter table public.vehicle_logs
  add column if not exists currency text;

comment on column public.communities.veh_unit     is '차량 거리 단위 — mi | km (저장은 늘 마일)';
comment on column public.communities.veh_currency is '앞으로 적을 정비 기록의 통화';
comment on column public.vehicles.owner_name      is '차량 명의';
comment on column public.vehicles.insurer         is '보험사';
comment on column public.vehicle_logs.currency    is '이 기록을 적을 때의 통화 (비어 있으면 $)';

--  예전 기록에 통화를 박아 둡니다 — 나중에 공동체 통화를 바꿔도
--  이 기록들이 덩달아 다른 돈으로 읽히지 않게.
update public.vehicle_logs set currency = '$' where currency is null and cost is not null;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='communities' and column_name in ('veh_unit','veh_currency')) as "공동체 설정 칸(2)",
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='vehicles' and column_name in ('owner_name','insurer')) as "명의·보험사(2)",
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='vehicle_logs' and column_name='currency') as "기록 통화(1)",
  (select count(*) from public.vehicle_logs where currency = '$') as "$ 로 표시한 예전 기록";

-- =====================================================================
--  실행한 뒤 관리자 → 공동체 설정 → 🚗 차량 에서 고르세요.
--  실행 전에는 예전 그대로 mi · $ 로 보이고, 저장할 때 "그것만 빼고
--  저장했어요" 라고 알려 줍니다 — 기록 자체는 늘 남습니다.
-- =====================================================================
