-- ══════════════════════════════════════════════════════════════
--  주간 기록 — 날짜가 붙은 데일리 기록 (공통 / 그룹별)
--  (개선창 ⑪ · 송희정 · 프로토스 · 2026-11-06)
-- ══════════════════════════════════════════════════════════════
--
--  바라던 것 : "시간표 일정을 바인더 기록하듯이 공동체 전체와 그룹별로
--   데일리 기록을 남기고 싶은데 날짜가 없네요. 11월 1주 2주 ..
--   한주씩 날짜와 함께 기록할수 있으면 좋겠어요"
--
--  지금 timetables 는 '매주 똑같은 수업표' 입니다 — day(요일)·period(교시)
--  만 있고 **날짜가 없습니다**. 그래서 지난주와 이번주를 구분할 수가 없습니다.
--  표를 고치지 않고, 날짜를 가진 표를 하나 새로 둡니다. 시간표는 그대로
--  수업표로 남고, 주간 기록은 그 옆에 쌓입니다.
--
--  group_id 가 비어 있으면 '공통(공동체 전체)' 기록입니다.
-- ══════════════════════════════════════════════════════════════

create table if not exists public.weekly_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null references public.communities(id) on delete cascade,
  group_id      uuid references public.student_groups(id) on delete cascade,  -- 비면 공통(전체)
  log_date      date not null,
  content       text not null default '',
  author_id     uuid references public.members(id) on delete set null,
  author_name   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

--  한 날짜·한 그룹에 한 칸만. group_id 가 null 이면 보통 unique 가 안 걸리니
--  빈 값을 가짜 uuid 로 바꿔서 건다.
create unique index if not exists weekly_logs_one_per_day
  on public.weekly_logs (community_id, coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), log_date);
create index if not exists weekly_logs_by_week
  on public.weekly_logs (community_id, log_date);

-- ── 누가 보고 누가 쓰나 ───────────────────────────────────────
--  보기 : 우리 공동체 사람 (수업표와 같은 결)
--  쓰기 : 간사 이상 — 학생·학부모는 못 씁니다
alter table public.weekly_logs enable row level security;

--  학사(출석부·시간표·기록) 를 쓸 수 있는 사람 = 간사 이상.
--  화면의 '학사관리' 메뉴가 이미 이 역할들에게만 열려 있습니다 — 서버를 거기에 맞춥니다.
--  (시간표 고치기 파일에도 똑같이 들어 있습니다. 어느 쪽을 먼저 깔아도 됩니다.)
create or replace function public.is_staff_of(p_comm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_role in ('super_admin', 'vice_admin')
             or ( me.community_id = p_comm
                  and me.community_role in ('community_admin', 'admin_officer', 'teacher', 'staff') ) ));
$$;

create policy weekly_logs_select on public.weekly_logs
  for select to authenticated
  using (public.mine_comm(community_id));

create policy weekly_logs_insert on public.weekly_logs
  for insert to authenticated
  with check (public.is_staff_of(community_id));

create policy weekly_logs_update on public.weekly_logs
  for update to authenticated
  using (public.is_staff_of(community_id))
  with check (public.is_staff_of(community_id));

create policy weekly_logs_delete on public.weekly_logs
  for delete to authenticated
  using (public.is_staff_of(community_id));

--  부총관리자는 '자기 소속 공동체' 에서만 씁니다 (다른 표들과 같은 선)
create policy weekly_logs_vice_comm_ins on public.weekly_logs
  as restrictive for insert to authenticated
  with check ( (not (select public.is_vice_admin()))
               or community_id = (select public.my_community_id()) );
create policy weekly_logs_vice_comm_upd on public.weekly_logs
  as restrictive for update to authenticated
  using ( (not (select public.is_vice_admin()))
          or community_id = (select public.my_community_id()) )
  with check ( (not (select public.is_vice_admin()))
               or community_id = (select public.my_community_id()) );
create policy weekly_logs_vice_comm_del on public.weekly_logs
  as restrictive for delete to authenticated
  using ( (not (select public.is_vice_admin()))
          or community_id = (select public.my_community_id()) );

grant select, insert, update, delete on public.weekly_logs to authenticated;
revoke truncate on public.weekly_logs from anon, authenticated;

--  고친 때를 적어 둔다
create or replace function public.weekly_logs_touch()
returns trigger language plpgsql
set search_path = public
as $$
begin new.updated_at := now(); return new; end
$$;

--  두 번 깔아도 터지지 않게 — 이미 있으면 넘어갑니다
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'weekly_logs_touch_trg'
                   and tgrelid = 'public.weekly_logs'::regclass) then
    create trigger weekly_logs_touch_trg before update on public.weekly_logs
      for each row execute function public.weekly_logs_touch();
  end if;
end $$;
