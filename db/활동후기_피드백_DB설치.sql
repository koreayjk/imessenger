-- =====================================================================
--  ✍️ 활동 후기 — 피드백 칸
--
--  후기는 '내가 무엇을 겪었나' 를 적는 글입니다. 그것만으로는 다음 활동이
--  나아지지 않습니다. 그래서 **같은 활동을 준비하는 쪽에 주는 말**을 따로
--  받습니다 — 무엇이 아쉬웠고, 내가 준비하는 사람이었다면 무엇을 다르게
--  했을지.
--
--  이 칸은 **간사 이상만** 봅니다. 아이들끼리 서로 보면 솔직한 말이
--  안 나옵니다. 쓴 본인은 제 것을 봅니다.
--
--  ⚠️ 줄(row) 자체가 이미 '본인 · 담임교사 · 관리자' 에게만 열려 있습니다
--     (writings_select). 그래서 다른 학생이 남의 피드백을 볼 길은 애초에
--     없습니다. 여기서는 칸만 더합니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
--  먼저 db/학생기록_독후감_활동후기_DB설치.sql 을 실행해 두셔야 합니다.
-- =====================================================================

alter table public.student_writings
  add column if not exists feedback text;

comment on column public.student_writings.feedback is
  '활동을 준비한 쪽에 주는 말(개선 제안). 간사 이상만 봅니다.';

-- (독후감에서 쓰던) 질문별 답변을 활동 후기에서도 씁니다 — 이어서 고칠 때
-- 질문마다 되돌려 놓으려면 답을 따로 들고 있어야 합니다.
alter table public.student_writings
  add column if not exists final_answers text;

comment on column public.student_writings.final_answers is
  '질문별 답변(JSON). 본문은 질문을 뺀 글만 남고, 고칠 때 이걸로 되돌립니다.';

notify pgrst, 'reload schema';


-- ── 확인 ─────────────────────────────────────────────────────────
select column_name as "칸", data_type as "자료형"
  from information_schema.columns
 where table_schema = 'public' and table_name = 'student_writings'
   and column_name in ('feedback','final_answers')
 order by 1;

--  누가 볼 수 있나 (줄 단위 규칙)
select policyname as "정책", cmd as "대상"
  from pg_policies
 where schemaname = 'public' and tablename = 'student_writings'
 order by 2, 1;
