-- =====================================================================
--  학생 기록 — 독후감 + 활동 후기
--  Supabase → SQL Editor 에 붙여넣고 실행하세요.
-- =====================================================================

-- 학생이 직접 쓰는 기록 (독후감/활동후기 공용)
create table if not exists public.student_writings (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  kind          text not null,        -- 'book'(독후감) | 'activity'(활동후기)
  category      text,                 -- activity: 분류 / book: 책 제목
  title         text,
  body          text,
  date          date,                 -- 작성일(권수 통계 기준)
  read_start    date,                 -- (독후감) 읽기 시작한 날
  read_end      date,                 -- (독후감) 다 읽은 날
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
create index if not exists idx_writings_member on public.student_writings (member_id, kind, date desc);

-- 이미 테이블이 있던 경우 컬럼 보강
alter table public.student_writings add column if not exists read_start date;
alter table public.student_writings add column if not exists read_end   date;

alter table public.student_writings enable row level security;
drop policy if exists writings_select on public.student_writings;
drop policy if exists writings_insert on public.student_writings;
drop policy if exists writings_update on public.student_writings;
drop policy if exists writings_delete on public.student_writings;

create policy writings_select on public.student_writings for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = student_writings.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
create policy writings_insert on public.student_writings for insert to authenticated with check (member_id = auth.uid());
create policy writings_update on public.student_writings for update to authenticated using (member_id = auth.uid());
create policy writings_delete on public.student_writings for delete to authenticated using (member_id = auth.uid());

-- 활동 후기 분류 (공동체별, 교사·관리자만 마스터 편집 가능)
create table if not exists public.review_categories (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  name          text not null,
  sort          int default 0,
  created_at    timestamptz default now()
);
alter table public.review_categories enable row level security;
drop policy if exists review_cat_read  on public.review_categories;
drop policy if exists review_cat_write on public.review_categories;
create policy review_cat_read on public.review_categories for select to authenticated using (true);
create policy review_cat_write on public.review_categories for all to authenticated
using      (exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff')))
with check (exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff')));

-- 기본 분류 시딩 (모든 공동체에, 이름 중복은 건너뜀)
insert into public.review_categories (community_id, name, sort)
select c.id, x.name, x.ord
from public.communities c
cross join (values
  ('선교',1),('봉사활동',2),('수련회/캠프',3),('예배/집회',4),
  ('체험학습',5),('견학/탐방',6),('특강/세미나',7),('문화체험',8),
  ('스포츠/야외활동',9),('기타',99)
) as x(name, ord)
where not exists (
  select 1 from public.review_categories rc where rc.community_id = c.id and rc.name = x.name
);

NOTIFY pgrst, 'reload schema';
