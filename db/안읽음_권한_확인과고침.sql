-- ════════════════════════════════════════════════════════════════════
--  🔧 unread_by_channel 권한 확인 · 고치기
--
--  서버 기록(Postgres 로그)에 이것이 쏟아졌습니다:
--      permission denied for function unread_by_channel   (42501)
--
--  이 함수가 막히면 앱이 '45일치 글 1000줄 받아 세기' 로 떨어집니다.
--  그런데 그 일은 읽음 표시가 바뀔 때마다 돌기 때문에, 사람이 여럿이면
--  서로를 깨워 눈덩이가 됩니다. 그러다 DB 가 숨이 차면 로그인(Auth)까지
--  같이 느려집니다 — 실제로 그렇게 됐습니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

-- ── ① 지금 상태 보기 ──────────────────────────────────────────────
select
  p.proname                                              as "함수",
  case p.prosecdef when true then 'definer' else 'invoker' end as "실행 주체",
  has_function_privilege('authenticated', p.oid, 'execute')    as "로그인한 사람이 부를 수 있나",
  has_function_privilege('anon',          p.oid, 'execute')    as "로그인 안 한 사람도 되나(되면 안 됨)"
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'unread_by_channel';
-- 함수가 아예 없으면 위가 0줄입니다 → db/안읽음_방별_DB설치.sql 을 먼저 돌리세요.

-- ── ② 고치기 ──────────────────────────────────────────────────────
do $$
begin
  if to_regprocedure('public.unread_by_channel()') is null then
    raise notice '함수가 없습니다 — db/안읽음_방별_DB설치.sql 을 먼저 돌려주세요';
    return;
  end if;
  -- 로그인 안 한 사람은 못 부르게, 로그인한 사람은 부를 수 있게
  revoke all on function public.unread_by_channel() from public, anon;
  grant execute on function public.unread_by_channel() to authenticated;
  raise notice '권한을 다시 맞췄습니다';
end $$;

notify pgrst, 'reload schema';

-- ── ③ 다시 보기 ───────────────────────────────────────────────────
select
  has_function_privilege('authenticated', 'public.unread_by_channel()', 'execute') as "이제 로그인한 사람은 ✅",
  has_function_privilege('anon',          'public.unread_by_channel()', 'execute') as "로그인 안 한 사람은 ❌ 여야";
