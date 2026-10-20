-- ════════════════════════════════════════════════════════════════════
--  🔖 북마크 · 🙈 나에게만 삭제
--
--  카톡 메뉴에 있는데 TCS 에 없던 둘입니다.
--
--  · 북마크 — 나중에 다시 찾을 메시지에 표를 해 둡니다. 나만 봅니다.
--  · 나에게만 삭제 — 내 화면에서만 치웁니다. 남의 화면에는 그대로
--    남습니다. (모두에게서 지우는 '삭제' 는 예전부터 있습니다)
--
--  둘 다 '나만의 표시' 라 한 표에 담습니다. 남의 줄은 보이지도,
--  써지지도 않습니다.
--
--  ⚠️ '나에게만 삭제' 는 글을 지우지 않습니다. 가린 표시만 남깁니다.
--     신고가 들어왔을 때 관리자가 무엇을 신고한 건지 알 수 있어야
--     하고, 한쪽이 치웠다고 대화가 끊기면 안 됩니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

create table if not exists public.my_message_marks (
  member_id   uuid not null,
  message_id  uuid not null,
  bookmarked  boolean not null default false,
  hidden      boolean not null default false,   -- 나에게만 삭제
  created_at  timestamptz default now(),
  primary key (member_id, message_id)
);

alter table public.my_message_marks enable row level security;
drop policy if exists my_message_marks_own on public.my_message_marks;
create policy my_message_marks_own on public.my_message_marks
  for all to authenticated
  using ( member_id = auth.uid() ) with check ( member_id = auth.uid() );

-- 북마크함을 열 때 '내 것만, 최근 것부터'
create index if not exists my_message_marks_book_idx
  on public.my_message_marks (member_id, bookmarked, created_at desc);

grant select, insert, update, delete on public.my_message_marks to authenticated;

notify pgrst, 'reload schema';

select '설치 끝 — 북마크와 나에게만 삭제를 쓸 수 있어요' as "결과";
