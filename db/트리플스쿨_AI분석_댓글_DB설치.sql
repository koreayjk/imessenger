-- =====================================================================
--  Triple School 최종 독후감 : ① AI 분석 결과 저장  ② 교직원 댓글(피드백)
--  · AI 분석은 한 번 돌리면 저장되어 다시 들어와도 그대로 보입니다.
--  · 댓글은 간사 이상(학생 제외)만 작성, 학생은 자기 것만 읽습니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- 교직원(간사 이상) 판별 헬퍼 — 이미 있으면 갱신
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

-- ─────────────────────────────────────────────────────────────
-- ① AI 분석 결과 (책 × 학생 당 1개, 다시 분석하면 덮어씀)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reading_ai_reviews (
  id               uuid primary key default gen_random_uuid(),
  book_id          uuid not null references public.reading_books(id) on delete cascade,
  student_id       uuid not null references public.members(id) on delete cascade,
  community_id     uuid,
  result           jsonb not null,            -- {likelihood,score,summary,signals,excerpts,questions}
  word_count       int,                       -- 분석 당시 독후감 단어 수(재제출 감지용)
  analyzed_by      uuid,
  analyzed_by_name text,
  created_at       timestamptz not null default now()
);
create unique index if not exists uq_reading_ai_reviews on public.reading_ai_reviews (book_id, student_id);

alter table public.reading_ai_reviews enable row level security;
drop policy if exists rair_select on public.reading_ai_reviews;
drop policy if exists rair_insert on public.reading_ai_reviews;
drop policy if exists rair_update on public.reading_ai_reviews;
drop policy if exists rair_delete on public.reading_ai_reviews;

-- 조회: 교직원만 (AI 판정은 학생에게 노출하지 않음)
create policy rair_select on public.reading_ai_reviews for select to authenticated
  using (public.is_school_staff());
create policy rair_insert on public.reading_ai_reviews for insert to authenticated
  with check (public.is_school_staff());
create policy rair_update on public.reading_ai_reviews for update to authenticated
  using (public.is_school_staff()) with check (public.is_school_staff());
create policy rair_delete on public.reading_ai_reviews for delete to authenticated
  using (public.is_school_staff());

-- ─────────────────────────────────────────────────────────────
-- ② 최종 독후감 댓글 (간사 이상 작성 · 학생은 자기 것 열람)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reading_report_comments (
  id            uuid primary key default gen_random_uuid(),
  book_id       uuid not null references public.reading_books(id) on delete cascade,
  student_id    uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  author_id     uuid not null,
  author_name   text,
  content       text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz
);
create index if not exists idx_rrc_book_student
  on public.reading_report_comments (book_id, student_id, created_at);

alter table public.reading_report_comments enable row level security;
drop policy if exists rrc_select on public.reading_report_comments;
drop policy if exists rrc_insert on public.reading_report_comments;
drop policy if exists rrc_update on public.reading_report_comments;
drop policy if exists rrc_delete on public.reading_report_comments;

-- 조회: 교직원 + 해당 학생 본인(자기가 받은 피드백은 볼 수 있어야 함)
create policy rrc_select on public.reading_report_comments for select to authenticated
  using (public.is_school_staff() or student_id = auth.uid());
-- 작성: 간사 이상만, 작성자는 본인으로 고정
create policy rrc_insert on public.reading_report_comments for insert to authenticated
  with check (public.is_school_staff() and author_id = auth.uid());
-- 수정/삭제: 본인이 쓴 댓글만 (단, 관리자는 모두 가능)
create policy rrc_update on public.reading_report_comments for update to authenticated
  using (author_id = auth.uid() and public.is_school_staff())
  with check (author_id = auth.uid() and public.is_school_staff());
create policy rrc_delete on public.reading_report_comments for delete to authenticated
  using (
    (author_id = auth.uid() and public.is_school_staff())
    or exists (select 1 from public.members me where me.id = auth.uid()
               and me.community_role in ('super_admin','community_admin'))
  );

NOTIFY pgrst, 'reload schema';
