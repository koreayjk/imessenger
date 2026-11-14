-- ══════════════════════════════════════════════════════════════
--  부총관리자 — 자기 그룹 안에서만 넘나들기
-- ══════════════════════════════════════════════════════════════
--
--  바라던 것 : "부총관리자는 그 그룹내에서 다른 공동체를 볼수 있게.
--   리뉴젠공동체에 속한 부총관리자는 리뉴젠공동체 전체 공동체를 볼수 있게"
--
--  지금 mine_comm 은 부총관리자에게 **모든 공동체**를 열어 줍니다.
--      or me.community_role in ('super_admin','vice_admin')
--  공동체가 한 갈래였을 땐 그게 곧 '전체' 였지만, 이제 갈래가 생겼습니다
--  (리뉴젠 공동체 18곳 · 해외 그룹 2곳). 리뉴젠 공동체 부총관리자가
--  해외 그룹까지 들여다보게 둘 이유가 없습니다.
--
--  그어지는 선
--   · 총관리자   : 전부 (그대로)
--   · 부총관리자 : **내 소속과 같은 갈래**의 공동체만
--   · 그 밖      : 내 소속 공동체만 (그대로)
--
--  mine_comm 은 정책 17개가 쓰고 있어서, 여기 한 자리만 고치면 일정·노트·
--  주간기록·자료실·학사까지 한꺼번에 같은 선을 따릅니다.
--
--  ⚠️ 지우고 다시 만들지 않고 **create or replace** 로 바꿉니다. 지우면
--     이 함수를 쓰는 정책 17개가 같이 떨어져 나갑니다.
--
--  ※ 관리 권한은 원래대로 '내 소속 공동체에서만' 입니다. 이 파일은
--    **보이는 범위**만 좁힙니다 — 다른 공동체에서의 쓰기는 각 표의
--    restrictive 정책(…_vice_comm_ins/upd/del)이 이미 막고 있습니다.
-- ══════════════════════════════════════════════════════════════

create or replace function public.mine_comm(cid uuid)
returns boolean
language sql stable parallel safe security definer
set search_path = public
as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_id = cid
             or me.community_role = 'super_admin'
             or ( me.community_role = 'vice_admin'
                  and public.community_kind_of(cid)
                      is not distinct from public.community_kind_of(me.community_id) ) ));
$$;
