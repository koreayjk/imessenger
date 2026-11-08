-- ═══════════════════════════════════════════════════════════════════
--  개인 일정은 나만 본다 (개선창 · 홍예원 간사)
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--    "개인 일정은 나만 볼 수 있게 세팅해주실 수 있을까요??
--     개인 일정도 모든 아이들이 볼 수 있게 되어 있더라구요!"
--
--  재 봤습니다 (운영 DB · 전부 롤백):
--    · 남이 내 개인 일정 보기   = 보인다  ← 사고
--    · 남이 내 개인 일정 고치기 = 1건 됨  ← 더 나쁘다
--    · 남이 내 개인 일정 지우기 = 1건 됨  ← 더 나쁘다
--
--  왜 그런가
--    events_select 는 제대로 가리고 있었습니다 —
--      (owner_id is null and mine_comm(...)) or owner_id = auth.uid()
--    그런데 events_comm 이라는 정책이 `for ALL` 로 mine_comm(community_id)
--    **하나만** 봅니다. PERMISSIVE 정책은 OR 로 묶이기 때문에, 같은
--    공동체이기만 하면 events_comm 이 전부 열어 줍니다. 식을 따로 계산해
--    보니 events_comm=true · events_select=false 였습니다.
--
--  고치는 법
--    events_comm 을 좁힙니다. 지우지 않고 ALTER 로 고칩니다 —
--    ⚠️ 같은 이름으로 다시 만들면 옛 설치 파일을 다시 돌릴 때 통째로
--       덮어써집니다. (부총관리자 권한에서 세 번 데인 자리입니다)
--
--  안 바뀌는 것
--    · 공동체 일정(owner_id 가 비어 있는 것)은 전과 똑같이 모두가 봅니다.
--    · 내 개인 일정은 내가 보고 고치고 지웁니다.
--    · 간사 이상이 공동체 일정을 고치고 지우는 것도 그대로입니다.
-- ═══════════════════════════════════════════════════════════════════

alter policy events_comm on public.events
  using (
    public.mine_comm(community_id)
    and (owner_id is null or owner_id = (select auth.uid()))
  )
  with check (
    public.mine_comm(community_id)
    and (owner_id is null or owner_id = (select auth.uid()))
  );

-- ── 확인 ─────────────────────────────────────────────────────────
do $$
declare q text;
begin
  select coalesce(qual,'') into q from pg_policies
   where schemaname='public' and tablename='events' and policyname='events_comm';
  if position('owner_id' in q) = 0 then
    raise exception 'events_comm 이 아직 owner_id 를 보지 않습니다';
  end if;
  raise notice '개인 일정은 이제 주인만 봅니다';
end $$;
