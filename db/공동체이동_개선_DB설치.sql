-- ════════════════════════════════════════════════════════════════
--  공동체 이동(무빙) 개선 — DB 설치
--  Supabase ▸ SQL Editor 에 통째로 붙여넣고 한 번 실행하면 됩니다.
--  여러 번 실행해도 안전합니다 (이미 있으면 건너뜁니다).
--
--  고치는 것 네 가지
--   ①  member_moves — 누가 언제 어디서 어디로 옮겼는지 남긴다
--   ②  옮겨 온 학생의 이전 생기부·출결·독서기록·활동후기를
--       새 공동체 교직원이 "읽을 수" 있게 한다 (쓰기는 안 됨)
--   ③  예치금·용돈 잔액을 옮길 때 자동 정산한다
--       (이전 공동체에서 빼고, 새 공동체에 같은 통화·같은 금액으로 넣음)
--   ④  부총관리자도 자기 묶음 안에서는 옮길 수 있게 한다
--       (묶음을 넘는 이동 — 예: 국내 → IM USA — 은 총관리자만)
-- ════════════════════════════════════════════════════════════════


-- ①  이동 이력 ────────────────────────────────────────────────
create table if not exists public.member_moves (
  id                uuid primary key default gen_random_uuid(),
  member_id         uuid not null references public.members(id) on delete cascade,
  from_community_id uuid references public.communities(id),
  to_community_id   uuid references public.communities(id),
  moved_at          timestamptz not null default now(),
  moved_by          uuid references public.members(id),
  note              text
);

create index if not exists member_moves_member_idx on public.member_moves (member_id);
create index if not exists member_moves_from_idx   on public.member_moves (from_community_id);
create index if not exists member_moves_to_idx     on public.member_moves (to_community_id);

alter table public.member_moves enable row level security;

-- 읽기: 본인, 떠난 공동체 교직원, 받은 공동체 교직원
do $$ begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='member_moves'
                    and policyname='member_moves_read') then
    create policy member_moves_read on public.member_moves
      for select using (
        member_id = (select auth.uid())
        or public.staff_of(from_community_id)
        or public.staff_of(to_community_id)
      );
  end if;
end $$;

-- 쓰기 정책은 두지 않습니다.
-- 이동 기록은 아래 admin_move_member_community 함수만 남깁니다.


-- ②  옮겨 온 학생의 이전 기록 읽기 ────────────────────────────
--
--  "지금 우리 공동체에 있는 학생이, 전에 있던 공동체에서 남긴 기록" 이면 읽게 한다.
--  A → B → C 로 두 번 옮겨도 C 교직원은 A·B 시절 기록을 다 읽습니다.
--  읽기 전용입니다 — 고치거나 지우는 것은 여전히 그 기록을 가진 공동체만 합니다.
--  상담기록 · 보건기록 · 관찰기록 · 노트 · 기도제목은 열지 않습니다.

create or replace function public.can_see_moved_record(p_student uuid, p_rec_comm uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_student is not null
     and p_rec_comm is not null
     and exists (
           select 1 from public.member_moves mm
            where mm.member_id = p_student
              and mm.from_community_id = p_rec_comm
         )
     and public.staff_of(public.member_community_of(p_student));
$$;

grant execute on function public.can_see_moved_record(uuid, uuid) to authenticated;

do $$
declare r record;
begin
  for r in
    select * from (values
      ('tcs_records',      'student_id'),   -- 생활기록부 (성적 · 모의고사 포함)
      ('attendance_daily', 'student_id'),   -- 출결
      ('reading_logs',     'student_id'),   -- 독서 기록
      ('student_writings', 'member_id')     -- 독후감 · 활동후기
    ) as v(tbl, col)
  loop
    begin
      if not exists (select 1 from pg_policies
                      where schemaname='public' and tablename=r.tbl
                        and policyname = r.tbl || '_moved_in_read') then
        execute format(
          'create policy %I on public.%I for select using (public.can_see_moved_record(%I, community_id))',
          r.tbl || '_moved_in_read', r.tbl, r.col);
      end if;
    exception when undefined_table or undefined_column then
      null;   -- 아직 안 깐 기능은 건너뜁니다
    end;
  end loop;
end $$;


-- ③④  옮기기 함수 — 정산 + 부총관리자 ─────────────────────────

create or replace function public.admin_move_member_community(
  p_member_id    uuid,
  p_community_id uuid,
  p_dry_run      boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  m          record;
  from_name  text;
  to_name    text;
  my_kind    text;
  leftovers  jsonb := '{}'::jsonb;
  readable   jsonb := '{}'::jsonb;
  settle     jsonb := '[]'::jsonb;
  unlinked   jsonb := '{}'::jsonb;
  n          bigint;
  r          record;
  b          record;
begin
  select id, name, email, community_id, community_role, status
    into m
    from public.members
   where id = p_member_id;
  if not found then
    raise exception '그 멤버를 찾을 수 없습니다' using errcode = 'P0002';
  end if;

  select name into to_name from public.communities where id = p_community_id;
  if not found then
    raise exception '옮길 공동체를 찾을 수 없습니다' using errcode = 'P0002';
  end if;
  select name into from_name from public.communities where id = m.community_id;

  -- ── 누가 옮길 수 있나 ──
  if not public.is_super_admin() then
    if not public.is_vice_admin() then
      raise exception '총관리자·부총관리자만 공동체를 옮길 수 있습니다' using errcode = '42501';
    end if;
    -- 부총관리자는 자기 묶음 안에서만
    my_kind := public.community_kind_of(public.my_community_id());
    if my_kind is null
       or public.community_kind_of(m.community_id) is distinct from my_kind
       or public.community_kind_of(p_community_id) is distinct from my_kind then
      raise exception '부총관리자는 자기 묶음 안에서만 옮길 수 있습니다. 묶음을 넘는 이동은 총관리자에게 부탁하세요'
        using errcode = '42501';
    end if;
  end if;

  -- 총관리자는 이 기능으로 못 옮긴다. 본인은 화면 위쪽 [공동체 전환] 을 쓴다.
  if m.community_role = 'super_admin' then
    raise exception '총관리자는 여기서 옮길 수 없습니다. 공동체 전환을 쓰세요' using errcode = '42501';
  end if;
  -- 부총관리자를 옮기는 것도 총관리자만
  if m.community_role = 'vice_admin' and not public.is_super_admin() then
    raise exception '부총관리자를 옮기는 것은 총관리자만 할 수 있습니다' using errcode = '42501';
  end if;

  if m.community_id is not distinct from p_community_id then
    raise exception '이미 % 에 있습니다', coalesce(to_name, '그 공동체') using errcode = '22023';
  end if;

  -- ── 새 공동체에서 "읽을 수 있게 되는" 기록 세기 ──
  for r in
    select * from (values
      ('tcs_records',      'student_id'),
      ('attendance_daily', 'student_id'),
      ('reading_logs',     'student_id'),
      ('student_writings', 'member_id')
    ) as v(tbl, col)
  loop
    begin
      execute format('select count(*) from public.%I where %I = $1', r.tbl, r.col)
        into n using p_member_id;
      if n > 0 then
        readable := readable || jsonb_build_object(r.tbl, n);
      end if;
    exception when undefined_table or undefined_column then
      null;
    end;
  end loop;

  -- ── 이전 공동체에만 남는 기록 세기 ──
  for r in
    select * from (values
      ('messages',          'sender_id'),
      ('allowance_entries', 'member_id'),
      ('deposit_entries',   'member_id'),
      ('prayers',           'member_id'),
      ('notes',             'user_id'),
      ('counseling_logs',   'student_id'),
      ('observation_logs',  'student_id'),
      ('health_logs',       'student_id')
    ) as v(tbl, col)
  loop
    begin
      execute format('select count(*) from public.%I where %I = $1', r.tbl, r.col)
        into n using p_member_id;
      if n > 0 then
        leftovers := leftovers || jsonb_build_object(r.tbl, n);
      end if;
    exception when undefined_table or undefined_column then
      null;
    end;
  end loop;

  -- ── 정산할 잔액 재기 (예치금) ──
  begin
    for b in
      select currency,
             sum(case when type = 'in' then amount else -amount end) as bal
        from public.deposit_entries
       where member_id = p_member_id
         and community_id is not distinct from m.community_id
       group by currency
      having sum(case when type = 'in' then amount else -amount end) <> 0
    loop
      settle := settle || jsonb_build_array(
        jsonb_build_object('kind', '예치금', 'currency', b.currency, 'amount', b.bal));
      if not p_dry_run then
        -- 이전 공동체에서 0 으로 맞춘다
        insert into public.deposit_entries
          (member_id, community_id, date, type, amount, currency, memo, created_by)
        values
          (p_member_id, m.community_id, current_date,
           case when b.bal > 0 then 'out' else 'in' end, abs(b.bal), b.currency,
           '공동체 이동 정산 — ' || coalesce(from_name,'(없음)') || ' → ' || to_name,
           auth.uid());
        -- 새 공동체에 같은 금액·같은 통화로 넣는다
        insert into public.deposit_entries
          (member_id, community_id, date, type, amount, currency, memo, created_by)
        values
          (p_member_id, p_community_id, current_date,
           case when b.bal > 0 then 'in' else 'out' end, abs(b.bal), b.currency,
           '공동체 이동 정산 — ' || coalesce(from_name,'(없음)') || ' 에서 넘어옴',
           auth.uid());
      end if;
    end loop;
  exception when undefined_table or undefined_column then
    null;
  end;

  -- ── 정산할 잔액 재기 (용돈) ──
  begin
    for b in
      select currency,
             sum(case when type = 'income' then amount else -amount end) as bal
        from public.allowance_entries
       where member_id = p_member_id
         and community_id is not distinct from m.community_id
       group by currency
      having sum(case when type = 'income' then amount else -amount end) <> 0
    loop
      settle := settle || jsonb_build_array(
        jsonb_build_object('kind', '용돈', 'currency', b.currency, 'amount', b.bal));
      if not p_dry_run then
        insert into public.allowance_entries
          (member_id, community_id, date, type, category, amount, currency, memo)
        values
          (p_member_id, m.community_id, current_date,
           case when b.bal > 0 then 'expense' else 'income' end, '기타', abs(b.bal), b.currency,
           '공동체 이동 정산 — ' || coalesce(from_name,'(없음)') || ' → ' || to_name);
        insert into public.allowance_entries
          (member_id, community_id, date, type, category, amount, currency, memo)
        values
          (p_member_id, p_community_id, current_date,
           case when b.bal > 0 then 'income' else 'expense' end, '기타', abs(b.bal), b.currency,
           '공동체 이동 정산 — ' || coalesce(from_name,'(없음)') || ' 에서 넘어옴');
      end if;
    end loop;
  exception when undefined_table or undefined_column then
    null;
  end;

  if p_dry_run then
    return jsonb_build_object(
      'dry_run',        true,
      'member_name',    m.name,
      'member_email',   m.email,
      'from_community', coalesce(from_name, '(없음)'),
      'to_community',   to_name,
      'readable',       readable,
      'leftovers',      leftovers,
      'settle',         settle
    );
  end if;

  -- ── 이전 공동체의 자리에서 떼어내기 ──

  -- 반 · 담임
  update public.members set group_id = null, homeroom_teacher_id = null where id = p_member_id;

  -- 이 사람이 이전 공동체에서 담임이었다면, 그 학생들의 담임 표시를 푼다
  begin
    update public.members set homeroom_teacher_id = null where homeroom_teacher_id = p_member_id;
    get diagnostics n = row_count;
    if n > 0 then unlinked := unlinked || jsonb_build_object('담임_해제된_학생', n); end if;
  exception when undefined_column then null;
  end;

  -- 채팅 채널 참여 (채널은 공동체 것이다)
  begin
    delete from public.channel_members where member_id = p_member_id;
    get diagnostics n = row_count;
    if n > 0 then unlinked := unlinked || jsonb_build_object('채널_참여', n); end if;
  exception when undefined_table or undefined_column then null;
  end;

  -- 담당교사 배정
  begin
    delete from public.student_homerooms where student_id = p_member_id or teacher_id = p_member_id;
    get diagnostics n = row_count;
    if n > 0 then unlinked := unlinked || jsonb_build_object('담당교사_배정', n); end if;
  exception when undefined_table or undefined_column then null;
  end;

  -- 개인 시간표 (이전 공동체의 학기·과목 기준이다)
  begin
    delete from public.student_timetables where member_id = p_member_id;
    get diagnostics n = row_count;
    if n > 0 then unlinked := unlinked || jsonb_build_object('개인_시간표', n); end if;
  exception when undefined_table or undefined_column then null;
  end;

  -- ── 이동 이력을 남긴다 (이게 있어야 새 공동체가 이전 기록을 읽는다) ──
  insert into public.member_moves (member_id, from_community_id, to_community_id, moved_by, note)
  values (p_member_id, m.community_id, p_community_id, auth.uid(),
          coalesce(from_name, '(없음)') || ' → ' || to_name);

  -- ── 옮기기 ──
  update public.members
     set community_id = p_community_id
   where id = p_member_id;

  return jsonb_build_object(
    'dry_run',        false,
    'member_name',    m.name,
    'member_email',   m.email,
    'from_community', coalesce(from_name, '(없음)'),
    'to_community',   to_name,
    'unlinked',       unlinked,
    'readable',       readable,
    'leftovers',      leftovers,
    'settle',         settle
  );
end $function$;

grant execute on function public.admin_move_member_community(uuid, uuid, boolean) to authenticated;


-- ⑤  이미 옮긴 사람 메우기 ────────────────────────────────────
--  이 설치 전에 옮긴 사람은 member_moves 에 기록이 없어서
--  새 공동체가 이전 기록을 읽지 못합니다.
--  지금 소속과 다른 공동체에 기록을 남긴 학생을 찾아 이력을 채워 둡니다.
insert into public.member_moves (member_id, from_community_id, to_community_id, moved_at, note)
select distinct t.student_id, t.community_id, mb.community_id,
       now(), '설치 전에 옮긴 것으로 보여 자동으로 채움'
  from public.tcs_records t
  join public.members mb on mb.id = t.student_id
 where t.community_id is not null
   and mb.community_id is not null
   and t.community_id <> mb.community_id
   and not exists (
     select 1 from public.member_moves mm
      where mm.member_id = t.student_id
        and mm.from_community_id = t.community_id
   );
