-- ═══════════════════════════════════════════════════════════════════
--  TRUNCATE 권한 거두기 — public 스키마 전체
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  왜 거두나
--    TRUNCATE 는 **RLS 를 통째로 무시합니다.** 정책을 아무리 잘 써 놔도
--    TRUNCATE 한 방이면 표가 비워집니다.
--    재 보니 public 의 88개 표에 anon(로그인 안 한 사람)·authenticated
--    두 역할 모두 TRUNCATE 가 열려 있었습니다 — members, messages,
--    channels 까지 포함해서.
--
--    지금 쓰는 REST(PostgREST)로는 TRUNCATE 를 부를 길이 없어서 당장
--    터지는 건 아닙니다. 하지만 권한이 있을 이유가 없고, 나중에 RPC 를
--    하나 잘못 만들면 그 길이 열립니다. 쓰지 않는 권한은 거둡니다.
--
--  무엇이 안 바뀌나
--    DELETE 는 그대로입니다. 앱이 줄을 지우는 건 전부 DELETE 라서
--    아무것도 깨지지 않습니다. service_role·postgres 도 그대로입니다
--    (엣지 함수와 마이그레이션이 쓰는 역할).
-- ═══════════════════════════════════════════════════════════════════

revoke truncate on all tables in schema public from anon, authenticated;

--  앞으로 만드는 표에도 TRUNCATE 가 붙지 않게
alter default privileges in schema public
  revoke truncate on tables from anon, authenticated;

-- ── 확인 ─────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n
    from information_schema.role_table_grants
   where table_schema='public' and privilege_type='TRUNCATE'
     and grantee in ('anon','authenticated');
  if n > 0 then
    raise exception 'TRUNCATE 가 아직 %건 남아 있습니다', n;
  end if;
  raise notice 'TRUNCATE 를 anon·authenticated 에서 모두 거뒀습니다';
end $$;
