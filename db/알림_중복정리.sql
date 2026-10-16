-- =====================================================================
--  🧹 알림 줄 중복 치우기 (한 번만 돌리면 됩니다)
--
--  왜 생겼나 — 휴대폰에서 '켜기' 를 연달아 누르면, 브라우저가 누를
--  때마다 새 '기기 주소' 를 내줍니다. 줄 하나가 기기 하나라, 그 사람은
--  메시지 하나에 알림을 그 수만큼 받습니다. (한 분은 20줄이었습니다)
--
--  코드는 고쳤습니다. 이미 쌓인 줄만 치웁니다.
--
--  ⚠️ 기기를 여럿 쓰는 분(노트북 + 휴대폰)의 줄은 지우면 안 됩니다.
--     그래서 '같은 사람 · 같은 길 · 2분 안에 생긴 것' 만 묶어서,
--     그중 가장 최근 것 하나만 남깁니다. 며칠 간격으로 켠 줄은
--     진짜 다른 기기이므로 건드리지 않습니다.
--
--  지워도 손해가 없습니다 — 그 기기에서 다시 켜면 새로 생깁니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- 같은 사람 · 같은 길 안에서, 바로 앞 줄과 2분 넘게 떨어져 있으면
-- 새 묶음으로 센다. (창함수는 겹쳐 쓸 수 없어 lag 를 먼저 구한다)
create or replace view public.v_push_bursts as
with lagged as (
  select id, member_id, kind, created_at,
         lag(created_at) over (partition by member_id, kind order by created_at) as prev
    from public.push_subscriptions
),
grouped as (
  select id, member_id, kind, created_at,
         sum(case when prev is null or created_at - prev > interval '2 minutes' then 1 else 0 end)
           over (partition by member_id, kind order by created_at
                 rows between unbounded preceding and current row) as grp
    from lagged
)
select id, member_id, kind, created_at, grp,
       row_number() over (partition by member_id, kind, grp order by created_at desc) as rn,
       count(*)     over (partition by member_id, kind, grp) as in_grp,
       min(created_at) over (partition by member_id, kind, grp) as grp_at
  from grouped;

-- ── 1) 먼저 무엇을 지울지 봅니다 (아무것도 안 고칩니다) ─────────────
select coalesce(m.name,'(알 수 없음)') as "사람",
       v.kind      as "길",
       v.in_grp    as "한꺼번에 생긴 줄",
       v.in_grp-1  as "지울 줄",
       v.grp_at    as "그때"
  from public.v_push_bursts v
  left join public.members m on m.id = v.member_id
 where v.in_grp > 1 and v.rn = 1
 order by 4 desc;

-- ── 2) 실제로 지웁니다 (묶음마다 가장 최근 것 하나만 남깁니다) ──────
delete from public.push_subscriptions
 where id in (select id from public.v_push_bursts where rn > 1);

drop view public.v_push_bursts;

-- ── 3) 치운 뒤 ──────────────────────────────────────────────────────
select coalesce(m.name,'(알 수 없음)') as "사람", count(*) as "남은 기기 줄"
  from public.push_subscriptions ps
  left join public.members m on m.id = ps.member_id
 group by 1 having count(*) > 1 order by 2 desc;

select kind as "길", count(*) as "기기 수"
  from public.push_subscriptions group by 1 order by 1;
