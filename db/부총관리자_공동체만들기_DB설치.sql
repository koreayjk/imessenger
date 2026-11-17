-- ═══════════════════════════════════════════════════════════════════
--  🏛️ 부총관리자도 공동체를 만들 수 있게
--
--  "부총관리자도 공동체를 만들수있는 권한을 줘"
--
--  다만 **자기 묶음(kind) 안에서만** 입니다.
--
--  왜 묶음을 제한하나 — 부총관리자가 보는 범위는 mine_comm 이 정하고,
--  그것은 공동체의 kind 로 가릅니다(리뉴젠 공동체 / 리뉴젠 아카데미 /
--  해외 그룹). 다른 묶음으로 만들면 **만든 본인이 그 공동체를 못 봅니다.**
--  만들자마자 사라지는 셈이라, 열어 두는 것이 오히려 덫입니다.
--
--  그대로 두는 것
--   · 지우기(communities_delete)        — 총관리자만
--   · 종류 바꾸기(communities_kind_super_only) — 총관리자만
--   · 남의 공동체 설정 고치기(can_edit_community) — 자기 공동체만
--  만드는 것과 없애는 것은 무게가 다릅니다.
--
--  두 번 돌려도 됩니다. drop 을 한 글자도 쓰지 않습니다
--  (Supabase 연결이 'drop' 을 보면 확인창을 띄워 설치가 멈춥니다).
-- ═══════════════════════════════════════════════════════════════════

alter policy communities_insert on public.communities
  with check (
    (select public.is_super_admin())
    or (
      (select public.is_vice_admin())
      and coalesce(kind, 'community')
          is not distinct from
          coalesce(public.community_kind_of((select public.my_community_id())), 'community')
    )
  );
