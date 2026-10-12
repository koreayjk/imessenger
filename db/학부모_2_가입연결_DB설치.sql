-- =====================================================================
--  👨‍👩‍👧 2단계 — 학부모 가입과 학생 연결
--
--  ※ 반드시 1단계(db/학부모_1_칸막이_DB설치.sql) 를 먼저 실행하세요.
--     칸막이 없이 학부모를 들이면 남의 집 아이 기록까지 열립니다.
--
--  가입 흐름
--    1) 학부모가 가입 화면에서 '학부모' 를 고르고
--       아이 이름 + 아이 생년월일을 적는다
--    2) 적은 내용이 맞는지 그 자리에서 확인해 준다 (목록은 안 보여준다)
--    3) 가입 신청이 '대기' 로 들어온다 — 적어 낸 내용이 함께 붙는다
--    4) 관리자가 관리 화면에서 아이를 확인하고 [연결하고 승인] 을 누른다
--       → 그때 비로소 부모–자녀 연결이 맺어진다
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 0. 1단계를 했는지 먼저 본다 ──────────────────────────────────
--  칸막이 없이 학부모를 들이면 남의 집 아이 기록까지 열립니다.
--  그래서 여기서 멈춥니다.
do $$
begin
  if to_regclass('public.student_parents') is null
     or to_regprocedure('public.staff_of(uuid)') is null then
    raise exception
      '먼저 db/학부모_1_칸막이_DB설치.sql 을 실행해주세요. 칸막이 없이 학부모를 받으면 남의 아이 기록까지 열립니다.';
  end if;
end $$;

-- ── 1. 가입할 때 적어 낸 내용 ─────────────────────────────────────
--  연결 자체가 아니라 '이렇게 적어 냈다' 는 기록입니다.
--  관리자가 확인하기 전까지는 아무 권한도 생기지 않습니다.
alter table public.members add column if not exists parent_claim_name  text;
alter table public.members add column if not exists parent_claim_birth date;
alter table public.members add column if not exists parent_claim_rel   text;

comment on column public.members.parent_claim_name is
  '학부모가 가입할 때 적어 낸 아이 이름. 관리자가 확인하고 student_parents 로 옮긴다.';

-- ── 2. 연결하고 승인 ─────────────────────────────────────────────
--  관리자가 누르는 단추 하나가 하는 일:
--    적어 낸 이름+생년월일로 그 공동체 학생을 찾고 → 연결하고 → 승인한다.
--  찾지 못하거나 둘 이상이면 아무것도 바꾸지 않고 이유를 돌려준다.
create or replace function public.approve_parent(p_parent uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  par   public.members%rowtype;
  hit   uuid;
  cnt   int;
begin
  if not public.can_admin_members() then
    return jsonb_build_object('ok', false, 'reason', '권한이 없어요');
  end if;

  select * into par from public.members where id = p_parent;
  if not found then return jsonb_build_object('ok', false, 'reason', '그 가입 신청을 찾을 수 없어요'); end if;
  if par.community_role <> 'parent' then
    return jsonb_build_object('ok', false, 'reason', '학부모 가입 신청이 아니에요');
  end if;
  -- 남의 공동체는 건드리지 못한다 (총관리자만 예외)
  if not public.is_super_admin() and par.community_id is distinct from public.my_community_id() then
    return jsonb_build_object('ok', false, 'reason', '다른 공동체의 신청이에요');
  end if;
  if par.parent_claim_name is null or par.parent_claim_birth is null then
    return jsonb_build_object('ok', false, 'reason', '적어 낸 아이 정보가 없어요 — 직접 연결해 주세요');
  end if;

  -- uuid 에는 min() 이 없다. 찾은 것을 모아서 센다.
  select count(*), (array_agg(m.id))[1] into cnt, hit
    from public.members m
   where m.community_id = par.community_id
     and m.community_role = 'student'
     and coalesce(m.status,'') <> 'removed'
     and m.birth_date = par.parent_claim_birth
     and lower(replace(m.name, ' ', '')) = lower(replace(par.parent_claim_name, ' ', ''));

  if cnt = 0 then
    return jsonb_build_object('ok', false, 'reason',
      format('%s (%s) 학생을 찾지 못했어요 — 이름이나 생년월일을 확인해 주세요',
             par.parent_claim_name, par.parent_claim_birth));
  end if;
  if cnt > 1 then
    return jsonb_build_object('ok', false, 'reason',
      format('%s (%s) 로 맞는 학생이 %s명이에요 — 직접 골라서 연결해 주세요',
             par.parent_claim_name, par.parent_claim_birth, cnt));
  end if;

  insert into public.student_parents (student_id, parent_id, relation, linked_by)
       values (hit, p_parent, coalesce(par.parent_claim_rel, '보호자'), auth.uid())
  on conflict (student_id, parent_id) do nothing;

  update public.members set status = 'approved' where id = p_parent;

  return jsonb_build_object('ok', true, 'student_id', hit,
                            'student_name', (select name from public.members where id = hit));
end $$;

revoke all on function public.approve_parent(uuid) from public;
grant execute on function public.approve_parent(uuid) to authenticated;

-- ── 3. 관리자가 직접 연결할 때 ───────────────────────────────────
--  이름이 겹치거나 아이가 둘 이상일 때 관리자가 손으로 잇습니다.
create or replace function public.link_parent(p_parent uuid, p_student uuid, p_relation text default '보호자')
returns jsonb
language plpgsql security definer set search_path = public as $$
declare s public.members%rowtype; p public.members%rowtype;
begin
  if not public.can_admin_members() then
    return jsonb_build_object('ok', false, 'reason', '권한이 없어요');
  end if;
  select * into p from public.members where id = p_parent;
  select * into s from public.members where id = p_student;
  if p.id is null or s.id is null then return jsonb_build_object('ok', false, 'reason', '사람을 찾을 수 없어요'); end if;
  if s.community_role <> 'student' then return jsonb_build_object('ok', false, 'reason', '학생이 아니에요'); end if;
  if p.community_id is distinct from s.community_id then
    return jsonb_build_object('ok', false, 'reason', '같은 공동체가 아니에요');
  end if;
  if not public.is_super_admin() and p.community_id is distinct from public.my_community_id() then
    return jsonb_build_object('ok', false, 'reason', '다른 공동체예요');
  end if;
  insert into public.student_parents (student_id, parent_id, relation, linked_by)
       values (p_student, p_parent, coalesce(p_relation,'보호자'), auth.uid())
  on conflict (student_id, parent_id) do update set relation = excluded.relation;
  return jsonb_build_object('ok', true, 'student_name', s.name);
end $$;

revoke all on function public.link_parent(uuid, uuid, text) from public;
grant execute on function public.link_parent(uuid, uuid, text) to authenticated;

-- ── 4. 학부모는 스스로 역할을 올릴 수 없다 ───────────────────────
--  members_insert 가 이미 super_admin·community_admin 을 막고 있지만,
--  'parent' 로 들어온 사람이 나중에 'teacher' 로 바꾸는 것도 막아 둡니다.
--  (역할 변경은 원래 관리자만 가능하지만, 한 겹 더 세워 둡니다.)
drop policy if exists members_parent_stays_parent on public.members;
create policy members_parent_stays_parent on public.members
  as restrictive for update to authenticated
  using ( true )
  with check (
    public.can_admin_members()
    or community_role is not distinct from public.member_role_of(id)
  );

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select '학부모 수' as "항목", count(*)::text as "값" from public.members where community_role = 'parent'
union all
select '맺어진 연결', count(*)::text from public.student_parents
union all
select '연결 기다리는 신청', count(*)::text from public.members
 where community_role = 'parent' and coalesce(status,'') = 'pending';

-- =====================================================================
--  다음: Edge Function `parent-verify` 를 배포하세요.
--  (가입 화면에서 "우리 아이가 맞는지" 확인해 주는 함수입니다.
--   배포하지 않아도 가입은 되고, 확인만 건너뜁니다.)
-- =====================================================================
