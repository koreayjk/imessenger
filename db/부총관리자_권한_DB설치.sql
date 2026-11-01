-- =====================================================================
--  👤 부총관리자 — 자기 공동체에선 관리자와 똑같이, 남의 공동체는 눈으로만
--
--  무엇이 문제였나
--    부총관리자(Clara)가 「관리자 페이지 → 멤버 → 승인」을 눌러도
--    “가입을 승인할 권한이 없어요” 가 떴습니다.
--
--    뿌리는 can_admin_members() 입니다. 이 함수는
--        community_role in ('super_admin','community_admin')
--    이라서 부총관리자가 빠져 있습니다. 그리고 members 표의 정책
--    대여섯 군데가 전부 이 함수 하나를 보고 있습니다.
--
--    지금까지는 members_update 안에
--        or (is_vice_admin() and community_id = my_community_id())
--    를 손으로 끼워 넣는 식으로 때웠습니다(db/부총관리자_멤버관리_복구.sql).
--    그런데 **허용 정책은 이름이 같으면 통째로 덮어쓰입니다.** 뒤에 깐
--    다른 설치 파일이 members_update 를 다시 만들 때마다 그 한 줄이
--    조용히 사라졌습니다. 실제로 지금 DB 에서도 또 사라져 있었습니다.
--    같은 자리를 세 번째 고치는 셈이라, 이번에는 방식을 바꿉니다.
--
--  이 파일이 하는 일
--    1) can_admin_members() 자체에 부총관리자를 넣습니다.
--       → members 정책을 한 줄도 건드리지 않아도 승인·거절·역할변경·
--         탈퇴가 전부 열립니다. 앞으로 누가 members_update 를 다시
--         만들어도 다시 닫히지 않습니다.
--
--    2) 대신 '공동체 울타리' 를 **따로 선 제한(restrictive) 정책**으로
--       세웁니다. community_id 칸이 있는 모든 표에 _vice_comm_ins /
--       _upd / _del 세 개를 깔아, 부총관리자가 **남의 공동체 행을 쓰는
--       것**만 막습니다. 읽기는 건드리지 않습니다.
--       이름이 달라서 다른 설치 파일과 부딪히지 않습니다. 그래서
--       1) 과 달리 이 울타리는 덮어쓰여 사라지지 않습니다.
--
--       ※ 자기가 당사자인 행(건 사람·받은 사람·학생·작성자…)은
--         예외로 둡니다. 안 그러면 다른 공동체 사람이 건 전화를
--         **받지도 못합니다.**
--
--    3) members·증명서·직인을 **다른 공동체 것도 볼 수** 있게 합니다.
--       (볼 수만 있습니다. 쓰기는 2) 의 울타리가 막습니다.)
--
--    4) student_parents(학생–보호자 연결)에는 community_id 칸이 없어
--       울타리가 닿지 않습니다. 학생의 공동체로 따로 묶습니다.
--       — 이건 관리자(community_admin)에게도 울타리가 됩니다.
--         지금은 남의 공동체 학생도 묶을 수 있게 열려 있습니다.
--
--    5) 저장용량 파일 지우기도 부총관리자는 자기 공동체만.
--
--    6) 총·부총관리자 자리를 **새로 꽂아 넣는 것**을 막습니다.
--       고치는 쪽(members_protect_superadmin_upd)만 막혀 있고
--       넣는 쪽은 뚫려 있었습니다.
--
--  바뀌지 않는 것
--    · 총관리자(super_admin) 는 전과 똑같이 어디든 됩니다.
--    · 부총관리자는 여전히 총·부총관리자 자리를 건드릴 수 없습니다
--      (members_protect_superadmin_upd/del 그대로).
--    · 학생·학부모·교사 권한은 한 칸도 바뀌지 않습니다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regprocedure('public.my_community_id()') is null
     or to_regprocedure('public.is_vice_admin()') is null
     or to_regprocedure('public.is_super_admin()') is null then
    raise exception '먼저 db/부총관리자_DB설치.sql 을 실행해주세요.';
  end if;
end $$;


-- ── 1. 부총관리자를 '멤버를 관리할 수 있는 사람' 에 넣는다 ──────────
--  공동체 범위는 여기서 보지 않습니다. 아래 2 번 울타리가 봅니다.
--  (함수 하나에 다 넣으면, members_update 를 덮어쓰는 다음 설치 파일이
--   또 권한을 날려 버립니다. 그래서 일부러 둘로 나눕니다.)
create or replace function public.can_admin_members()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','community_admin','vice_admin'));
$$;
grant execute on function public.can_admin_members() to authenticated;

-- 어느 멤버가 어느 공동체 소속인지 (학생–보호자 묶기에 씁니다)
create or replace function public.member_community_of(target uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select community_id from public.members where id = target;
$$;
grant execute on function public.member_community_of(uuid) to authenticated;


-- ── 2. 공동체 울타리 — 남의 공동체는 쓰지 못한다 ────────────────────
--  community_id 칸이 있는 모든 표에 제한 정책 세 개를 깝니다.
--  제한 정책은 서로 AND 로 묶이므로, 원래 정책이 무엇이든 이 조건을
--  통과해야만 쓸 수 있습니다. 그리고 읽기(select)에는 걸지 않습니다.
--
--  조건
--    · 부총관리자가 아니면          → 무조건 통과 (아무것도 안 바뀜)
--    · community_id 가 비어 있으면  → 통과 (공동체에 속하지 않은 행)
--    · 내 공동체면                  → 통과
--    · 내가 당사자인 행이면         → 통과
--
--  마지막 줄이 없으면 다른 공동체 사람이 건 전화(calls)를 받을 수도,
--  남의 공동체 방에서 내가 쓴 글을 고칠 수도 없게 됩니다.
do $$
declare
  r      record;
  c      text;
  own    text;
  guard  text;
  cand   text[] := array[
    'caller_id','callee_id','student_id','member_id','user_id','owner_id',
    'author_id','submitter_id','reporter_id','requester_id','parent_id',
    'created_by','teacher_id','uploaded_by','writer_id','actor_id','sender_id'
  ];
begin
  for r in
    select cl.oid, cl.relname::text as tbl
      from pg_class cl
      join pg_namespace n on n.oid = cl.relnamespace
      join pg_attribute a on a.attrelid = cl.oid
                         and a.attname = 'community_id'
                         and a.attnum > 0 and not a.attisdropped
     where n.nspname = 'public' and cl.relkind = 'r' and cl.relrowsecurity
     order by 1
  loop
    own := '';

    --  members 는 행의 id 가 곧 사람입니다. 다른 표의 id 는 아닙니다.
    if r.tbl = 'members' then
      own := own || ' or id = (select auth.uid())';
    end if;

    foreach c in array cand loop
      if exists (select 1 from pg_attribute a
                  where a.attrelid = r.oid and a.attname = c
                    and a.attnum > 0 and not a.attisdropped
                    and a.atttypid = 'uuid'::regtype) then
        own := own || format(' or %I = (select auth.uid())', c);
      end if;
    end loop;

    --  (select …) 로 감싸는 까닭 — 이렇게 쓰면 행마다 다시 부르지 않고
    --  질의 시작 때 한 번만 셈합니다. 정책 177 개가 깔리므로 차이가 큽니다.
    guard := '(not (select public.is_vice_admin()))'
          || ' or community_id is null'
          || ' or community_id = (select public.my_community_id())'
          || own;

    execute format('drop policy if exists %I on public.%I', r.tbl || '_vice_comm_ins', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_vice_comm_upd', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_vice_comm_del', r.tbl);

    execute format(
      'create policy %I on public.%I as restrictive for insert to authenticated with check (%s)',
      r.tbl || '_vice_comm_ins', r.tbl, guard);
    execute format(
      'create policy %I on public.%I as restrictive for update to authenticated using (%s) with check (%s)',
      r.tbl || '_vice_comm_upd', r.tbl, guard, guard);
    execute format(
      'create policy %I on public.%I as restrictive for delete to authenticated using (%s)',
      r.tbl || '_vice_comm_del', r.tbl, guard);
  end loop;
end $$;


-- ── 3. 보기 — 다른 공동체도 눈으로는 본다 ───────────────────────────
drop policy if exists members_read_guard on public.members;
create policy members_read_guard on public.members
  as restrictive for select to authenticated
  using (
    auth.uid() is not null
    and ( id = auth.uid()
          or public.can_view_all_communities()
          or community_id = public.my_community_id() )
  );

drop policy if exists members_select on public.members;
create policy members_select on public.members
  for select to authenticated
  using (
    id = auth.uid()
    or public.can_view_all_communities()
    or ( community_id = public.my_community_id()
         and ( not public.is_parent()
               or id in (select public.my_children())
               or community_role in ('super_admin','vice_admin','community_admin',
                                     'admin_officer','teacher','staff') ) )
  );

--  증명서·직인도 눈으로는 본다 (쓰기는 2 번 울타리가 막습니다)
drop policy if exists certificates_select on public.certificates;
create policy certificates_select on public.certificates
  for select to authenticated
  using ( public.is_cert_issuer()
          and ( community_id = public.my_community_id()
                or public.can_view_all_communities() ) );

drop policy if exists org_seals_select on public.org_seals;
create policy org_seals_select on public.org_seals
  for select to authenticated
  using ( community_id = public.my_community_id()
          or public.can_view_all_communities() );


-- ── 4. 학생–보호자 묶기 — 공동체 밖은 묶지 못한다 ───────────────────
--  이 표에는 community_id 칸이 없어 2 번 울타리가 닿지 않습니다.
--  학생이 어느 공동체인지를 보고 직접 묶습니다.
drop policy if exists student_parents_write on public.student_parents;
create policy student_parents_write on public.student_parents
  for all to authenticated
  using (
    public.is_super_admin()
    or ( public.can_admin_members()
         and public.member_community_of(student_id) = public.my_community_id() )
  )
  with check (
    public.is_super_admin()
    or ( public.can_admin_members()
         and public.member_community_of(student_id) = public.my_community_id() )
  );


-- ── 5. 저장용량 파일 지우기 — 부총관리자도 자기 공동체만 ────────────
create or replace function public.can_delete_storage_file(obj_name text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and me.community_role in ('super_admin','vice_admin','community_admin')
       and ( me.community_role = 'super_admin'
             or me.community_id = public.storage_file_community(obj_name) )
  );
$$;
grant execute on function public.can_delete_storage_file(text) to authenticated;


-- ── 6. 총·부총관리자 자리는 새로 꽂아 넣을 수도 없다 ────────────────
--  고치는 쪽(members_protect_superadmin_upd)만 막혀 있고, 넣는 쪽은
--  뚫려 있었습니다. 관리자가 'super_admin' 행을 그냥 만들 수 있었습니다.
drop policy if exists members_protect_superadmin_ins on public.members;
create policy members_protect_superadmin_ins on public.members
  as restrictive for insert to authenticated
  with check (
    coalesce(community_role, 'student') not in ('super_admin','vice_admin')
    or public.is_super_admin()
  );
