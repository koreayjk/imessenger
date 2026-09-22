-- =====================================================================
--  💱 공동체 통화 설정
--   한국 공동체는 원(₩), 미국 공동체는 달러($) 처럼
--   공동체마다 쓰는 돈 단위를 하나로 정해 둡니다.
--   이 값을 정하면 용돈·예치금·학비·매점의 금액 입력칸에서
--   ₩/$ 고르는 버튼이 사라지고 전부 이 단위로 기록됩니다.
--
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.communities add column if not exists currency text not null default '원';

-- 이미 쓰던 공동체는 기존 기록을 보고 기본값을 잡아 준다.
-- (용돈·예치금·학비에 달러 기록이 더 많으면 달러로)
do $$
declare c record; won_n int; usd_n int;
begin
  for c in select id from public.communities loop
    select
      coalesce(sum(case when cur = '원' then n else 0 end), 0),
      coalesce(sum(case when cur = '$'  then n else 0 end), 0)
      into won_n, usd_n
    from (
      select coalesce(currency,'원') as cur, count(*) as n
        from public.allowance_entries where community_id = c.id group by 1
      union all
      select coalesce(currency,'원'), count(*)
        from public.deposit_entries  where community_id = c.id group by 1
      union all
      select coalesce(currency,'원'), count(*)
        from public.tuition_bills    where community_id = c.id group by 1
    ) t;
    if usd_n > won_n then
      update public.communities set currency = '$' where id = c.id;
    end if;
  end loop;
exception when undefined_table then
  -- 아직 설치 안 된 표가 있으면 기본값(원) 그대로 둔다
  null;
end $$;

notify pgrst, 'reload schema';

-- =====================================================================
--  끝. 관리자 → 공동체 설정 에서 원/달러를 바꿀 수 있습니다.
--  바꾸면 그때 있는 기록을 현재 환율로 한꺼번에 변환할지 물어봅니다.
-- =====================================================================
