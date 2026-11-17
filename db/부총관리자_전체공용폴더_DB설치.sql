-- ═══════════════════════════════════════════════════════════════════
--  🌐 부총관리자가 자기 묶음의 전체 공용 자료실 폴더를 넣게
--
--  "부총관리자가 자기 묶음의 전체 공용 폴더를 넣을수있게 해줘"
--
--  ⚠️ app_settings 는 **여러 설정이 함께 사는 표**입니다. 역할만 보고
--     열면 다른 설정(열쇠·토큰 같은 것)까지 건드릴 수 있게 됩니다.
--     그래서 열쇠(key)를 **자기 묶음 것 하나**로 못 박습니다 —
--       drive_shared_folder_id_<내 묶음>
--
--  지우기(app_settings_delete)는 총관리자에게 그대로 둡니다.
--  화면의 「비우기」 는 값을 빈 것으로 덮어쓰는 것이라 update 로 됩니다.
--
--  두 번 돌려도 됩니다. drop 을 한 글자도 쓰지 않습니다
--  (Supabase 연결이 'drop' 을 보면 확인창을 띄워 설치가 멈춥니다).
--
--  운영에서 사람 흉내로 재 보았습니다 (글은 전부 되돌림):
--    ① 자기 묶음 넣기 됨    ② 고치기·비우기 1줄
--    ③ 남의 묶음 막힘       ④ 다른 설정(aim_secret_key) 막힘
--    ⑤ 부총관리자 지우기 0줄 ⑥ 일반 공동체 관리자 막힘
--    ⑦ 총관리자는 전과 같음
-- ═══════════════════════════════════════════════════════════════════
do $$
declare
  cond text := $f$
    (select public.is_super_admin())
    or (
      (select public.is_vice_admin())
      and key = 'drive_shared_folder_id_'
                || coalesce(public.community_kind_of((select public.my_community_id())), 'community')
    )
  $f$;
begin
  execute format('alter policy app_settings_insert on public.app_settings with check (%s)', cond);
  execute format('alter policy app_settings_update on public.app_settings using (%s) with check (%s)', cond, cond);
end $$;
