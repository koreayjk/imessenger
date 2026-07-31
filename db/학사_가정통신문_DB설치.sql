-- =====================================================================
--  TCS 학사관리 — 가정통신문 테이블
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

create table if not exists public.newsletters (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  group_id      uuid,            -- 대상 반(student_groups.id). null = 전체(모든 가족)
  title         text not null,
  body          text,
  sent_date     date,            -- 발송일
  author_name   text,
  created_by    uuid,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_newsletters_comm
  on public.newsletters (community_id, sent_date desc);

-- RLS — 로그인 사용자 접근 허용 (소규모 학교 내부용)
-- 가족(학생·학부모)이 홈 화면에서 읽을 수 있어야 하므로 select 도 authenticated 에 허용.
alter table public.newsletters enable row level security;

drop policy if exists newsletters_rw on public.newsletters;
create policy newsletters_rw on public.newsletters
  for all to authenticated
  using (true) with check (true);
