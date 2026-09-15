-- ═══════════════════════════════════════════════════════════════
--  멤버 공동체 이동 — 총관리자가 사람을 다른 공동체로 옮긴다
--  (가입할 때 공동체를 잘못 고른 경우를 바로잡는 용도)
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 [Run] 한 번이면 끝납니다.
--  여러 번 실행해도 안전합니다.
--
--  ※ db/총관리자_보호.sql 을 먼저 실행해 두셔야 합니다 (is_super_admin 함수).
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────
-- 1) 사람 찾기 — 이름이나 이메일로 모든 공동체를 뒤진다
--
--    RLS 때문에 총관리자도 "지금 들어가 있는 공동체"의 멤버만 보입니다.
--    잘못 등록된 사람은 딴 공동체에 있으니 목록에 안 나오죠.
--    그래서 서버 함수로 찾습니다. (총관리자만 호출 가능)
-- ───────────────────────────────────────────────────────────────
create or replace function public.admin_find_members(p_q text)
returns table (
  id              uuid,
  name            text,
  email           text,
  community_role  text,
  status          text,
  community_id    uuid,
  community_name  text,
  created_at      timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := lower(btrim(coalesce(p_q, '')));
begin
  if not public.is_super_admin() then
    raise exception '총관리자만 쓸 수 있습니다' using errcode = '42501';
  end if;
  if length(q) < 2 then
    raise exception '두 글자 이상 입력해 주세요' using errcode = '22023';
  end if;

  return query
  select m.id, m.name, m.email, m.community_role, m.status,
         m.community_id, c.name, m.created_at
  from public.members m
  left join public.communities c on c.id = m.community_id
  where lower(coalesce(m.email, '')) like '%' || q || '%'
     or lower(coalesce(m.name , '')) like '%' || q || '%'
  order by m.created_at
  limit 50;
end $$;

revoke all on function public.admin_find_members(text) from public, anon;
grant execute on function public.admin_find_members(text) to authenticated;


-- ───────────────────────────────────────────────────────────────
-- 2) 공동체 옮기기
--
--    옮기면 이전 공동체의 "자리"에서 떼어냅니다 —
--      · 반(group_id) · 담임 · 채팅 채널 참여 · 개인 시간표
--    이전 공동체가 그 사람에 대해 써 둔 기록(생기부·출결·상담 등)은
--    그 공동체의 기록이므로 따라가지 않고 그대로 남습니다.
--    남는 기록이 있으면 결과에 개수를 알려 줍니다.
--
--    p_dry_run = true 로 부르면 아무것도 바꾸지 않고 "옮기면 이렇게 된다"만
--    돌려줍니다. 화면에서 확인 창을 띄울 때 씁니다.
-- ───────────────────────────────────────────────────────────────
create or replace function public.admin_move_member_community(
  p_member_id    uuid,
  p_community_id uuid,
  p_dry_run      boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  m          record;
  from_name  text;
  to_name    text;
  leftovers  jsonb := '{}'::jsonb;
  unlinked   jsonb := '{}'::jsonb;
  n          bigint;
  r          record;
begin
  if not public.is_super_admin() then
    raise exception '총관리자만 공동체를 옮길 수 있습니다' using errcode = '42501';
  end if;

  select id, name, email, community_id, community_role, status
    into m
    from public.members
   where id = p_member_id;
  if not found then
    raise exception '그 멤버를 찾을 수 없습니다' using errcode = 'P0002';
  end if;

  -- 총관리자는 이 기능으로 못 옮긴다. 본인은 화면 위쪽 [공동체 전환] 을 쓴다.
  if m.community_role = 'super_admin' then
    raise exception '총관리자는 여기서 옮길 수 없습니다. 공동체 전환을 쓰세요' using errcode = '42501';
  end if;

  select name into to_name from public.communities where id = p_community_id;
  if not found then
    raise exception '옮길 공동체를 찾을 수 없습니다' using errcode = 'P0002';
  end if;
  select name into from_name from public.communities where id = m.community_id;

  if m.community_id is not distinct from p_community_id then
    raise exception '이미 % 에 있습니다', coalesce(to_name, '그 공동체') using errcode = '22023';
  end if;

  -- ── 이전 공동체에 남게 될 기록 세기 ──
  for r in
    select * from (values
      ('messages',          'sender_id'),
      ('tcs_records',       'student_id'),
      ('attendance_daily',  'student_id'),
      ('reading_logs',      'student_id'),
      ('student_writings',  'member_id'),
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
      null;   -- 아직 안 깐 기능은 건너뛴다
    end;
  end loop;

  if p_dry_run then
    return jsonb_build_object(
      'dry_run',        true,
      'member_name',    m.name,
      'member_email',   m.email,
      'from_community', coalesce(from_name, '(없음)'),
      'to_community',   to_name,
      'leftovers',      leftovers
    );
  end if;

  -- ── 이전 공동체의 자리에서 떼어내기 ──

  -- 반 · 담임 (이전 공동체의 student_groups / members 를 가리키고 있다)
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
    'leftovers',      leftovers
  );
end $$;

revoke all on function public.admin_move_member_community(uuid, uuid, boolean) from public, anon;
grant execute on function public.admin_move_member_community(uuid, uuid, boolean) to authenticated;

NOTIFY pgrst, 'reload schema';

-- ── 확인 ──
-- 아래가 2줄 나오면 설치 완료입니다.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('admin_find_members', 'admin_move_member_community')
order by routine_name;
