-- =====================================================================
--  TCS 학사관리 — 담당교사(담임) 배정용 컬럼
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
--  members 테이블에 nullable 컬럼 하나만 추가합니다 (기존 데이터 영향 없음).
-- =====================================================================

alter table public.members
  add column if not exists homeroom_teacher_id uuid;

-- (선택) 담당교사로 학생을 빠르게 찾기 위한 인덱스
create index if not exists idx_members_homeroom
  on public.members (homeroom_teacher_id);
