-- ═══════════════════════════════════════════════════════════════════
--  되돌리기 — db/트렁케이트_거두기_DB설치.sql 을 취소합니다
--
--  ⚠️ 보통은 쓸 일이 없습니다. 거두기 때문에 뭔가 깨졌을 때만 쓰세요.
--     거두기 전(2026-11-08) 상태 그대로 돌려놓습니다: public 의 88개
--     표에 anon·authenticated 두 역할의 TRUNCATE 를 다시 줍니다.
-- ═══════════════════════════════════════════════════════════════════

grant truncate on all tables in schema public to anon, authenticated;

alter default privileges in schema public
  grant truncate on tables to anon, authenticated;
