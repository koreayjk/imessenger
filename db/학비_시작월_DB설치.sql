-- =====================================================================
--  학비: 학생별 '납부 시작월' 컬럼 추가
--  어떤 학생은 5월부터 시작 → 그 이전 달은 미납으로 잡지 않도록 구분합니다.
--  members.tuition_start_ym = 'YYYY-MM' (비어있으면 '이전부터' = 해당 연도 전체 대상)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

alter table public.members add column if not exists tuition_start_ym text;

NOTIFY pgrst, 'reload schema';
