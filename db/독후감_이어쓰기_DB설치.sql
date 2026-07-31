-- =====================================================================
--  독후감 이어쓰기 — 읽은 만큼 남기는 진행 메모(누적 → 완성 독후감)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요.
--  (student_writings 의 각 '책' 아래에 메모가 쌓입니다)
-- =====================================================================

create table if not exists public.book_report_notes (
  id           uuid primary key default gen_random_uuid(),
  writing_id   uuid not null references public.student_writings(id) on delete cascade,
  member_id    uuid not null references public.members(id) on delete cascade,
  community_id uuid,
  date         date,
  pages        text,            -- 읽은 범위(선택) 예: '51~80'
  content      text,
  created_at   timestamptz default now()
);
create index if not exists idx_booknotes_writing on public.book_report_notes (writing_id, date, created_at);
create index if not exists idx_booknotes_member  on public.book_report_notes (member_id);

alter table public.book_report_notes enable row level security;
drop policy if exists booknotes_select on public.book_report_notes;
drop policy if exists booknotes_insert on public.book_report_notes;
drop policy if exists booknotes_update on public.book_report_notes;
drop policy if exists booknotes_delete on public.book_report_notes;

-- 조회: 본인 + 담당교사(단일/다중) + 관리자
create policy booknotes_select on public.book_report_notes for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members s where s.id = book_report_notes.member_id and s.homeroom_teacher_id = auth.uid())
  or exists (select 1 from public.student_homerooms h where h.student_id = book_report_notes.member_id and h.teacher_id = auth.uid())
  or exists (select 1 from public.members me where me.id = auth.uid() and me.community_role in ('super_admin','community_admin','admin_officer'))
);
-- 추가/수정/삭제: 본인만
create policy booknotes_insert on public.book_report_notes for insert to authenticated with check (member_id = auth.uid());
create policy booknotes_update on public.book_report_notes for update to authenticated using (member_id = auth.uid());
create policy booknotes_delete on public.book_report_notes for delete to authenticated using (member_id = auth.uid());

-- 마무리 정리의 질문별 답변 저장(재편집 시 각 칸 복원용). 없어도 body로 동작.
alter table public.student_writings add column if not exists final_answers text;

NOTIFY pgrst, 'reload schema';
