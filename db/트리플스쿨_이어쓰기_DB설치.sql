-- =====================================================================
--  트리플스쿨 독후 '이어쓰기' — 읽은 날짜별 진행 메모 (최종 독후감은 reading_logs)
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행 안전)
-- =====================================================================

create table if not exists public.reading_notes (
  id            uuid primary key default gen_random_uuid(),
  book_id       uuid not null references public.reading_books(id) on delete cascade,
  member_id     uuid not null references public.members(id) on delete cascade,
  community_id  uuid,
  date          date,
  pages         text,           -- 읽은 범위(선택) 예: '51~80'
  content       text,
  created_at    timestamptz default now()
);
create index if not exists idx_readingnotes_book on public.reading_notes (member_id, book_id, date, created_at);

alter table public.reading_notes enable row level security;
drop policy if exists readingnotes_select on public.reading_notes;
drop policy if exists readingnotes_insert on public.reading_notes;
drop policy if exists readingnotes_update on public.reading_notes;
drop policy if exists readingnotes_delete on public.reading_notes;

-- 조회: 본인 + 담당교사·교직원·관리자
create policy readingnotes_select on public.reading_notes for select to authenticated
using (
  member_id = auth.uid()
  or exists (select 1 from public.members me where me.id = auth.uid()
             and me.community_role in ('super_admin','community_admin','admin_officer','teacher','staff'))
);
-- 작성/수정/삭제: 본인만
create policy readingnotes_insert on public.reading_notes for insert to authenticated
  with check (member_id = auth.uid());
create policy readingnotes_update on public.reading_notes for update to authenticated
  using (member_id = auth.uid());
create policy readingnotes_delete on public.reading_notes for delete to authenticated
  using (member_id = auth.uid());

NOTIFY pgrst, 'reload schema';
