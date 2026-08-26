-- =====================================================================
--  Triple School 필독서: 책 추가/수정/삭제 권한을 교직원 전체로 확대
--  대상: 총관리자·관리자·행정담당자·교사·간사 (학생 제외)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전, 기존 정책에 추가로 허용)
-- =====================================================================

-- 교직원 판별 헬퍼 (영문 community_role 또는 한글 role 중 하나라도 교직원)
create or replace function public.is_school_staff()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff')
        or me.role in ('총관리자','관리자','행정담당자','교사','간사')
      )
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

alter table public.reading_books enable row level security;

-- 조회: 로그인 사용자 모두
drop policy if exists reading_books_select_all on public.reading_books;
create policy reading_books_select_all on public.reading_books
  for select to authenticated using (true);

-- 추가/수정/삭제: 교직원(간사 포함)
drop policy if exists reading_books_staff_insert on public.reading_books;
create policy reading_books_staff_insert on public.reading_books
  for insert to authenticated with check (public.is_school_staff());

drop policy if exists reading_books_staff_update on public.reading_books;
create policy reading_books_staff_update on public.reading_books
  for update to authenticated using (public.is_school_staff()) with check (public.is_school_staff());

drop policy if exists reading_books_staff_delete on public.reading_books;
create policy reading_books_staff_delete on public.reading_books
  for delete to authenticated using (public.is_school_staff());

NOTIFY pgrst, 'reload schema';
