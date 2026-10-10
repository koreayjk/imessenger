-- =====================================================================
--  💬 결재 문서에 의견 달기
--
--  요청 (개선창 · 이단비 · 더초즌)
--   "결재 완료 후 의견란 작성할 수 있도록 공간이 있었으면 좋겠습니다.
--    결재 전에는 의견을 적을 수 있는 란이 있는데 모든 결재선이
--    완료된 후에 없어지네요."
--
--  맞습니다. 지금 의견칸은 '내 결재 차례'일 때만 나옵니다. 결재가 끝나면
--  그 문서에는 아무도 한 줄도 더 쓸 수 없습니다. 집행 결과나 뒤늦게 붙는
--  영수증 이야기를 적을 자리가 없습니다.
--
--  그래서 문서마다 의견 쓰는 자리를 따로 둡니다.
--  결재 중에도, 끝난 뒤에도 쓸 수 있습니다.
--  결재선의 '결재 의견'(승인·반려할 때 적는 것)은 그대로 둡니다 —
--  그건 결재 기록이고, 이건 그 뒤의 이야기입니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

create table if not exists public.approval_notes (
  id           uuid primary key default gen_random_uuid(),
  doc_id       uuid not null references public.approval_docs(id) on delete cascade,
  community_id uuid not null,
  author_id    uuid,
  author_name  text,
  body         text not null,
  created_at   timestamptz not null default now()
);
create index if not exists approval_notes_doc_idx on public.approval_notes (doc_id, created_at);

comment on table public.approval_notes is
  '결재 문서에 붙이는 의견. 결재가 끝난 뒤에도 쓸 수 있다.';

alter table public.approval_notes enable row level security;

-- 보기 — 그 문서를 볼 수 있는 사람 (결재 문서와 같은 기준)
drop policy if exists approval_notes_select on public.approval_notes;
create policy approval_notes_select on public.approval_notes
  for select to authenticated
  using ( public.appr_is_staff(community_id) );

-- 쓰기 — 본인 이름으로만
drop policy if exists approval_notes_insert on public.approval_notes;
create policy approval_notes_insert on public.approval_notes
  for insert to authenticated
  with check ( author_id = auth.uid() and public.appr_is_staff(community_id) );

-- 고치기·지우기 — 쓴 사람과 관리자
drop policy if exists approval_notes_update on public.approval_notes;
create policy approval_notes_update on public.approval_notes
  for update to authenticated
  using ( author_id = auth.uid() )
  with check ( author_id = auth.uid() );

drop policy if exists approval_notes_delete on public.approval_notes;
create policy approval_notes_delete on public.approval_notes
  for delete to authenticated
  using (
    author_id = auth.uid()
    or public.can_admin_members()
    or (public.is_vice_admin() and public.appr_is_staff(community_id))
  );

grant select, insert, update, delete on public.approval_notes to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ──
select polname as "정책",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end as "대상"
  from pg_policy where polrelid = 'public.approval_notes'::regclass order by 2,1;

-- =====================================================================
--  결재 문서를 열면 맨 아래에 '의견' 칸이 생깁니다.
--  PDF 로 뽑을 때도 '결재 의견' 아래에 같이 찍힙니다.
-- =====================================================================
