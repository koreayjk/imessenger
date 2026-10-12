-- =====================================================================
--  🧱 1단계 — 칸막이: "내 것만" 보이게
--
--  학부모님을 받기 전에 먼저 해야 하는 일입니다.
--
--  지금은 같은 공동체에 로그인만 하면 — 학생이든 누구든 — 남의
--  생활기록부·출석부·보건·상담·학비가 API 로 전부 읽힙니다.
--  화면에서 안 보일 뿐입니다. (출결·보건·상담·학비·출결신청은
--  아예 'using (true)' 라서 다른 공동체 사람에게도 열려 있습니다.)
--
--  그대로 학부모님을 들이면 남의 집 아이 기록까지 열립니다.
--  그래서 표마다 칸막이를 세웁니다.
--
--    교직원  → 우리 공동체 전체       (지금과 같음)
--    학생    → 자기 것만
--    학부모  → 연결된 내 아이 것만    (2단계에서 화면을 붙입니다)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 1. 부모–자녀 연결표 ───────────────────────────────────────────
--  부모 한 분이 아이 여럿, 아이 하나에 아버지·어머니 둘 다 가능해야
--  하므로 연결표로 둡니다.
create table if not exists public.student_parents (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.members(id) on delete cascade,
  parent_id   uuid not null references public.members(id) on delete cascade,
  relation    text,                       -- '부' | '모' | '보호자'
  linked_by   uuid,                       -- 연결을 승인한 관리자
  created_at  timestamptz not null default now(),
  unique (student_id, parent_id)
);
create index if not exists student_parents_parent_idx on public.student_parents (parent_id);
create index if not exists student_parents_student_idx on public.student_parents (student_id);

comment on table public.student_parents is
  '학부모 계정과 학생을 잇는 표. 이 연결이 학부모가 볼 수 있는 범위를 정한다.';

-- ── 2. 판단 함수 ─────────────────────────────────────────────────
--  set-returning 으로 두는 이유: 행마다 부르면 느립니다. 한 번 평가하고
--  끝나도록 `in (select ...)` 으로 씁니다.

-- 이 공동체의 교직원인가 (공동체 전체를 볼 수 있는 사람)
create or replace function public.staff_of(cid uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and ( me.community_role in ('super_admin','vice_admin')
          or ( me.community_id = cid
               and me.community_role in ('community_admin','admin_officer','teacher','staff') ) )
  );
$$;

-- 내 아이들
create or replace function public.my_children() returns setof uuid
language sql stable security definer parallel safe set search_path = public as $$
  select sp.student_id from public.student_parents sp where sp.parent_id = auth.uid();
$$;

-- 나는 학부모인가
create or replace function public.is_parent() returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.members me
                  where me.id = auth.uid() and me.community_role = 'parent');
$$;

-- 연결표 자체의 권한: 내 연결만 본다. 연결을 만들고 지우는 건 관리자.
alter table public.student_parents enable row level security;
drop policy if exists student_parents_select on public.student_parents;
create policy student_parents_select on public.student_parents for select to authenticated
  using ( parent_id = auth.uid()
          or student_id = auth.uid()
          or exists (select 1 from public.members s
                      where s.id = public.student_parents.student_id
                        and public.staff_of(s.community_id)) );
drop policy if exists student_parents_write on public.student_parents;
create policy student_parents_write on public.student_parents for all to authenticated
  using ( public.can_admin_members() ) with check ( public.can_admin_members() );
grant select, insert, update, delete on public.student_parents to authenticated;

-- ── 3. 칸막이 세우기 ─────────────────────────────────────────────
--  표에 남아 있는 정책을 **전부 걷어내고** 하나만 새로 답니다.
--  정책은 여럿이면 OR 로 합쳐지기 때문에, 옛 정책을 하나라도 남기면
--  칸막이가 그만큼 뚫립니다.
create or replace function public._tcs_wall(tbl text, pred_using text, pred_check text)
returns text language plpgsql as $$
declare p record; n int := 0;
begin
  if to_regclass('public.'||tbl) is null then return tbl || ' — 표가 없어 건너뜀'; end if;
  for p in select polname from pg_policy where polrelid = ('public.'||tbl)::regclass loop
    execute format('drop policy %I on public.%I', p.polname, tbl); n := n + 1;
  end loop;
  execute format('alter table public.%I enable row level security', tbl);
  execute format('create policy %I on public.%I for all to authenticated using (%s) with check (%s)',
                 tbl || '_wall', tbl, pred_using, pred_check);
  execute format('grant select, insert, update, delete on public.%I to authenticated', tbl);
  return tbl || ' — 옛 정책 ' || n || '개 걷고 칸막이 1개';
end $$;

-- 학생 본인도 보는 것 (교직원 + 본인)
select public._tcs_wall(t,
  'public.staff_of(community_id) or student_id = auth.uid()',
  'public.staff_of(community_id) or student_id = auth.uid()') as "칸막이"
  from unnest(array['tcs_records','reading_logs']) t

union all
-- 학생 본인은 보기만, 고치는 건 교직원
select public._tcs_wall(t,
  'public.staff_of(community_id) or student_id = auth.uid()',
  'public.staff_of(community_id)')
  from unnest(array['attendance_daily','health_logs']) t

union all
-- 교직원만 (교사가 적는 기록 — 학생이 보면 솔직하게 못 적는다)
select public._tcs_wall(t,
  'public.staff_of(community_id)',
  'public.staff_of(community_id)')
  from unnest(array['counseling_logs','observation_logs']) t

union all
-- 학비 — 교직원 + 학생 본인 + 그 아이의 학부모
select public._tcs_wall('tuition_bills',
  'public.staff_of(community_id) or student_id = auth.uid() or student_id in (select public.my_children())',
  'public.staff_of(community_id)')

union all
-- 출결 신청 — 학생이 직접 올린다
select public._tcs_wall('leave_requests',
  'public.staff_of(community_id) or student_id = auth.uid()',
  'public.staff_of(community_id) or student_id = auth.uid()');

drop function if exists public._tcs_wall(text,text,text);

-- ── 4. 멤버 표 — 학부모는 내 아이와 선생님만 ──────────────────────
--  기존 구성원에게는 지금과 똑같이 보입니다. 학부모만 좁힙니다.
drop policy if exists members_select on public.members;
create policy members_select on public.members
  for select to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or ( community_id = public.my_community_id()
         and ( not public.is_parent()
               or id in (select public.my_children())
               or community_role in ('super_admin','vice_admin','community_admin',
                                     'admin_officer','teacher','staff') ) )
  );

--  남의 인적사항 고치기 — 지금은 같은 공동체면 누구나 남의 이름·연락처·
--  보호자 전화번호를 고칠 수 있습니다 (역할·상태만 못 바꿉니다).
--  본인과 교직원만 남깁니다.
drop policy if exists members_update on public.members;
create policy members_update on public.members
  for update to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or public.staff_of(community_id)
  )
  with check (
    public.can_admin_members()
    or ( community_role is not distinct from public.member_role_of(id)
         and status     is not distinct from public.member_status_of(id) )
  );

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
-- 칸막이가 선 표와 정책 수 (표마다 1개여야 합니다)
select c.relname as "표", count(p.polname) as "정책 수"
  from pg_class c left join pg_policy p on p.polrelid = c.oid
 where c.relname in ('tcs_records','reading_logs','attendance_daily','health_logs',
                     'counseling_logs','observation_logs','tuition_bills','leave_requests')
 group by c.relname order by 1;

-- community_id 가 비어 있는 행이 있으면 아무에게도 안 보입니다. 0 이어야 합니다.
select 'tcs_records' as "표", count(*) as "공동체 비어 있는 행" from public.tcs_records where community_id is null
union all select 'attendance_daily', count(*) from public.attendance_daily where community_id is null
union all select 'tuition_bills',    count(*) from public.tuition_bills    where community_id is null
union all select 'leave_requests',   count(*) from public.leave_requests   where community_id is null;

-- =====================================================================
--  이걸 실행하면 학생은 자기 것만, 교직원은 지금처럼 전부 보게 됩니다.
--  화면은 달라지지 않습니다 — 원래 그렇게 보여주고 있었으니까요.
--  달라지는 건 "API 로 긁으면 다 나오던 것"이 막힌다는 점입니다.
-- =====================================================================
