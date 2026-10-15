-- =====================================================================
--  🎨 채팅 — 굵게 · 밑줄 · 색 · 형광펜
--
--  요청 (개선창)
--   "Bold, Underline, word size, italic, even changing word color to
--    red, yellow, green, blue, or highlight… so we can put emphases on
--    words when we are sending announcement to make them more readable"
--   "green Title for dorms message, red for emergency message,
--    blue for KFD related… it would also make it easier to find history
--    messages when needed!"
--
--  꾸민 글은 HTML 로 저장합니다. 그냥 두면 예전 메시지까지 HTML 로
--  읽어 버리므로, '이 줄은 꾸민 글' 이라는 표시가 필요합니다.
--  칸이 비어 있으면 지금까지처럼 그냥 글자로 봅니다.
--
--  ⚠️ 저장할 때와 보여줄 때 모두 위생 처리(imSanitizeHtml)를 거칩니다.
--     스크립트·iframe·onclick 같은 건 들어오지 못합니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.messages add column if not exists format text;

comment on column public.messages.format is
  '비어 있으면 그냥 글자. html 이면 꾸민 글(저장·표시 모두 위생 처리를 거친다).';

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select column_name as "칸", data_type as "자료형"
  from information_schema.columns
 where table_schema='public' and table_name='messages'
   and column_name in ('format','edited_at','hidden_at')
 order by 1;

-- =====================================================================
--  채팅 입력창 왼쪽 ＋ 에 '🎨 꾸며서 쓰기' 가 생깁니다.
-- =====================================================================
