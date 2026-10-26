-- =====================================================================
--  ✅ 5단계가 제대로 들어갔는지 확인 — 읽기만 합니다. 아무것도 안 고칩니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요.
-- =====================================================================

select
  (select case when pg_get_functiondef(p.oid) like '%<> ''parent''%'
                and pg_get_functiondef(p.oid) like '%admin_officer%'
               then '✅ 들어갔습니다' else '❌ 아직 예전 can_dm 입니다' end
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'can_dm')           as "학부모 1:1 제한",
  (select case when exists (
            select 1 from pg_policies
             where schemaname = 'public' and tablename = 'allowance_entries'
               and policyname = 'allowance_select' and qual like '%my_children%')
               then '✅ 열렸습니다' else '❌ 아직 닫혀 있습니다' end) as "아이 용돈 보기";

--  실제로 누구에게 1:1 을 걸 수 있는지 — 학부모 한 사람을 골라 세어 봅니다.
--  '막힘' 칸에 학생·학부모만 있고, 교직원이 끼어 있지 않아야 맞습니다.
with p as (select id, community_id from public.members
            where community_role = 'parent' and coalesce(status,'active') <> 'removed'
            limit 1)
select coalesce(m.community_role,'(없음)')                    as "상대 역할",
       count(*)                                                as "사람 수",
       case when m.community_role in ('super_admin','vice_admin','community_admin',
                                      'admin_officer','teacher','staff')
            then '✅ 1:1 됨' else '🚫 막힘' end                as "결과"
  from p join public.members m
    on m.community_id = p.community_id and m.id <> p.id
   and coalesce(m.status,'active') <> 'removed'
 group by 1, 3
 order by 3 desc, 1;
