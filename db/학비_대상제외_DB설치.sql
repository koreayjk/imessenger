-- =====================================================================
--  🚫 학비 대상 제외 — 같은 그룹 안에도 학비를 내지 않는 분이 있습니다
--
--  members.tuition_exempt = true  → 학비 납부 현황판에서 숨기고,
--                                   미납·예상수입 계산에서도 뺍니다.
--  지우는 게 아니라 꺼 두는 것이라, 언제든 되돌릴 수 있습니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.members
  add column if not exists tuition_exempt boolean not null default false;

comment on column public.members.tuition_exempt is
  '학비 대상이 아님 — 납부 현황판에서 숨기고 미납 계산에서 뺀다';

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select case when exists (
         select 1 from information_schema.columns
          where table_schema='public' and table_name='members'
            and column_name='tuition_exempt')
       then '✅ 칸이 생겼습니다' else '❌ 아직 없습니다' end as "학비 대상 제외",
       (select count(*) from public.members where tuition_exempt) as "지금 빼 둔 사람";

-- =====================================================================
--  실행하기 전에는 이름 앞 ✓ 를 눌러도 "DB 설치가 필요해요" 가 뜹니다.
--  권한은 따로 손대지 않습니다 — members 를 고칠 수 있는 사람(관리자·
--  행정담당)만 바꿀 수 있고, 그 규칙은 이미 걸려 있습니다.
-- =====================================================================
