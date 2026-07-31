-- =====================================================================
--  학사력(공유 캘린더) — 일정 분류 컬럼 추가
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
--  기존 events 테이블에 category 컬럼만 추가합니다(데이터 유지).
-- =====================================================================

alter table public.events add column if not exists category text;
-- category 예: 예배/집회, 시험, 행사, 방학/휴일, 현장학습, 회의, 기타

NOTIFY pgrst, 'reload schema';
