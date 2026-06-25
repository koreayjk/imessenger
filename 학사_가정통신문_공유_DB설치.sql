-- =====================================================================
--  TCS 학사관리 — 가정통신문 "공개 공유 링크" 기능
--  (이미 newsletters 테이블을 만든 뒤에 실행하세요)
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행.
-- =====================================================================

-- 공유 여부 플래그
alter table public.newsletters
  add column if not exists is_public boolean not null default false;

-- 로그인하지 않은(anon) 방문자는 "공유된" 통신문만 읽을 수 있도록 허용.
-- (교사가 '공유' 버튼을 누른 통신문만 is_public = true 가 됩니다)
drop policy if exists newsletters_public_read on public.newsletters;
create policy newsletters_public_read on public.newsletters
  for select to anon
  using (is_public = true);

-- 참고:
--  * 공유를 해제(is_public = false)하면 즉시 비로그인 열람이 차단됩니다.
--  * 기존 authenticated 정책(newsletters_rw)은 그대로 둡니다.
