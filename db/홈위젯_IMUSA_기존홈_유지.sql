-- ═══════════════════════════════════════════════════════════════
--  IM USA 홈을 지금 모습 그대로 고정
--
--  홈 위젯이 생기기 전에는 모든 공동체가 똑같은 홈(맥체인 · SVM D-DAY ·
--  가정통신문 · 주간 일정표)을 봤습니다. 이제 아직 안 꾸민 공동체는
--  "홈을 꾸며보세요" 안내를 보게 됩니다.
--
--  IM USA 는 그 배치를 계속 쓰고 싶으므로, 여기서 명시적으로 저장해 둡니다.
--  ※ 배포 전에 실행하시면 IM USA 홈이 잠깐이라도 비지 않습니다.
--
--  Supabase → SQL Editor 에 붙여넣고 [Run]. 여러 번 실행해도 안전합니다.
--  ※ db/홈위젯_DB설치.sql 을 먼저 실행해 두셔야 합니다.
-- ═══════════════════════════════════════════════════════════════

update public.communities
   set home_widgets = '[
         {"k":"mccheyne","w":1},
         {"k":"dday","w":1,"cfg":{"title":"SVM 컨퍼런스","date":"2026-11-20"}},
         {"k":"newsletter","w":2},
         {"k":"schedule","w":2}
       ]'::jsonb
 where id = '00000000-0000-0000-0000-000000000001'
   and home_widgets is null;    -- 이미 꾸며 뒀다면 건드리지 않는다

-- ── 확인 ──
-- IM USA 줄에 위젯 4개가 들어가 있으면 완료입니다.
select name,
       case when home_widgets is null then '(아직 안 꾸밈 — 홈에 안내가 뜹니다)'
            else jsonb_array_length(home_widgets)::text || '개 위젯' end as 홈배치
from public.communities
order by name;
