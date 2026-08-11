-- =====================================================================
--  트리플스쿨 도서 추가: Heaven's Heroes (David Shibley) → Step 3 · Disciple
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 중복 안 됨)
-- =====================================================================
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3, 'Disciple School', 'Heaven''s Heroes', 'David Shibley', 'New Leaf Press', 999
where not exists (
  select 1 from public.reading_books
  where title = 'Heaven''s Heroes' and step = 3 and category = 'Disciple School'
);

NOTIFY pgrst, 'reload schema';
