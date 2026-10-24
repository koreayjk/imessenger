-- =====================================================================
--  🔒 5단계 — 학부모의 1:1 은 교직원에게만 · 🐷 아이 용돈기입장 열기
--
--  두 가지를 합니다.
--
--  1) 학부모가 낀 1:1 대화는 상대가 교직원(교사·간사·행정담당·관리자)
--     일 때만 됩니다. 지금까지는 학부모가 공동체 명단에서 아무나 —
--     남의 집 아이나 다른 학부모까지 — 골라 1:1 을 틀 수 있었습니다.
--
--  2) 아이의 용돈기입장을 그 아이의 부모가 볼 수 있게 엽니다.
--     3단계에서는 일부러 닫아 두었던 것을 여는 것입니다. 보기만 되고,
--     적고 고치는 것은 여전히 아이와 교직원만 합니다.
--
--  ※ 1단계(칸막이)를 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regprocedure('public.my_children()') is null then
    raise exception '먼저 db/학부모_1_칸막이_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- ── 1. 누구와 1:1 을 틀 수 있나 ───────────────────────────────────
--  화면(index.html 의 canDmMember)과 같은 규칙입니다. 한쪽만 고치면
--  버튼은 사라져도 서버는 받아 줘서, 손으로 부르면 그대로 뚫립니다.
create or replace function public.can_dm(p_other uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1
      from public.members me
      join public.members o on o.id = p_other
     where me.id = auth.uid()
       and me.id <> o.id
       and coalesce(o.status,  'active') <> 'removed'
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_id = o.community_id
             or me.community_role in ('super_admin','vice_admin') )
       -- 학생 × 학생 은 막는다. role 이 비어 있을 수 있으니 coalesce —
       -- NULL = '학생' 은 거짓이 아니라 '모름' 이라서 조건 전체를 망칩니다.
       and not ( (coalesce(me.community_role,'') = 'student' or coalesce(me.role,'') = '학생')
                 and (coalesce(o.community_role,'') = 'student' or coalesce(o.role,'') = '학생') )
       -- 🔒 학부모가 낀 1:1 은 상대가 교직원일 때만. 양쪽 다 본다 —
       --    내가 학부모일 때도, 상대가 학부모일 때도 똑같이 막는다.
       and ( coalesce(me.community_role,'') <> 'parent'
             or o.community_role in ('super_admin','vice_admin','community_admin',
                                     'admin_officer','teacher','staff') )
       and ( coalesce(o.community_role,'') <> 'parent'
             or me.community_role in ('super_admin','vice_admin','community_admin',
                                      'admin_officer','teacher','staff') )
       and coalesce(o.community_role,'') <> 'store_bot'
  );
$$;
grant execute on function public.can_dm(uuid) to authenticated;

-- ── 2. 아이 용돈기입장 — 그 아이의 부모도 볼 수 있게 ────────────────
--  3단계에서 닫아 두었던 것을 엽니다. 보기만 더합니다.
drop policy if exists allowance_select on public.allowance_entries;
create policy allowance_select on public.allowance_entries for select to authenticated
using (
  member_id = auth.uid()
  or member_id in (select public.my_children())
  or public.is_homeroom_of(member_id)
  or public.staff_of(community_id)
);
--  넣고 고치고 지우는 정책은 건드리지 않습니다 — 학부모는 보기만 합니다.

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select tablename as "표", policyname as "정책", cmd as "무엇"
  from pg_policies
 where schemaname = 'public' and tablename = 'allowance_entries'
 order by 2;

--  학부모 한 사람을 골라, 공동체 안에서 1:1 을 틀 수 있는 사람이
--  교직원뿐인지 세어 봅니다. '학부모아님' 이 0 이어야 맞습니다.
with p as (select id, community_id from public.members
            where community_role = 'parent' limit 1)
select m.community_role as "상대 역할", count(*) as "사람 수",
       case when m.community_role in ('super_admin','vice_admin','community_admin',
                                      'admin_officer','teacher','staff')
            then '1:1 됨' else '막힘' end as "결과"
  from p join public.members m on m.community_id = p.community_id and m.id <> p.id
 group by 1 order by 1;

-- =====================================================================
--  이걸 실행하면
--    · 학부모 화면의 ＋ 1:1 목록에 선생님·간사님·관리자만 남습니다.
--    · '내 아이' 에 🐷 용돈기입장 칸이 생깁니다.
--  실행 전에는 용돈 칸이 "아직 적은 용돈 내역이 없어요" 로만 보입니다.
-- =====================================================================
