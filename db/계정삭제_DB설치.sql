-- =====================================================================
--  계정 삭제 (Google Play 필수 요건)
--   로그인이 있는 앱은 "앱 안에서 계정을 지울 수 있는 길"이 반드시 있어야 합니다.
--
--   이 스크립트는 본인이 자기 계정을 지우는 함수 하나를 만듭니다.
--   앱은 delete-account Edge Function 을 부르고, 그 함수가 이걸 호출합니다.
--
--   설계 메모
--   · 개인 소유 기록(노트·할일·기도·목표·메시지 …)은 지웁니다.
--   · 출결·평가·상담·보건·학비 같은 '공동체가 보존하는 기록'은 남습니다.
--     학교가 학생 기록을 학생 마음대로 지울 수 있으면 안 되기 때문입니다.
--     대신 members 행에서 신원 정보를 지워 누구인지 알 수 없게 만듭니다.
--   · 총관리자는 바로 못 나갑니다. 공동체가 주인을 잃기 때문에,
--     권한을 넘긴 뒤에 탈퇴하도록 막습니다.
--   · 아직 설치하지 않은 표가 있어도 그 표만 건너뛰고 계속 진행합니다.
--     (기능을 나중에 추가해도 이 파일을 고칠 필요가 없게)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid      uuid := auth.uid();
  rec      record;
  removed  jsonb := '{}'::jsonb;
  n        bigint;
  cols     text[];
  sets     text[] := '{}';
  c        text;
  member_deleted boolean := false;
begin
  if uid is null then
    raise exception '로그인이 필요합니다.' using errcode = '28000';
  end if;

  -- 총관리자는 권한을 넘긴 뒤에만 나갈 수 있습니다.
  if exists (
    select 1 from public.members
    where id = uid and (community_role = 'super_admin' or role = '총관리자')
  ) then
    raise exception '총관리자는 다른 사람에게 권한을 넘긴 뒤에 탈퇴할 수 있습니다.'
      using errcode = 'P0001';
  end if;

  -- ── 1. 개인이 소유한 기록 지우기 ────────────────────────────────
  --   (표, 소유자컬럼) 목록. 없는 표·없는 컬럼은 조용히 건너뜁니다.
  for rec in
    select * from (values
      ('notes',               'user_id'),
      ('note_templates',      'user_id'),
      ('todos',               'created_by'),
      ('monthly_goals',       'created_by'),
      ('prayers',             'member_id'),
      ('poll_votes',          'member_id'),
      ('channel_reads',       'member_id'),
      ('channel_members',     'member_id'),
      ('message_reads',       'member_id'),
      ('message_reactions',   'member_id'),
      ('messages',            'sender_id'),
      ('student_timetables',  'member_id'),
      ('improvement_comments','created_by'),
      ('improvements',        'created_by')
    ) as x(tbl, col)
  loop
    begin
      execute format('delete from public.%I where %I = $1', rec.tbl, rec.col) using uid;
      get diagnostics n = row_count;
      if n > 0 then
        removed := removed || jsonb_build_object(rec.tbl, n);
      end if;
    exception
      when undefined_table or undefined_column then null;   -- 아직 없는 기능
      when insufficient_privilege then null;
    end;
  end loop;

  -- ── 2. 회원 행 ──────────────────────────────────────────────────
  --   먼저 통째로 지워 봅니다. 학사·재정 기록이 이 행을 참조하고 있으면
  --   지울 수 없으므로(외래키), 그때는 신원 정보만 지웁니다.
  begin
    delete from public.members where id = uid;
    member_deleted := true;
  exception when foreign_key_violation then
    member_deleted := false;
  end;

  if not member_deleted then
    -- members 에 실제로 있는 컬럼만 골라서 비웁니다.
    select array_agg(column_name::text) into cols
      from information_schema.columns
     where table_schema = 'public' and table_name = 'members';

    foreach c in array array[
      'email','phone','address','birth_date','birth','gender',
      'photo_url','avatar_url','profile_url',
      'guardian_name','guardian_phone','guardian','parents','note','memo'
    ] loop
      if c = any(cols) then
        sets := sets || format('%I = null', c);
      end if;
    end loop;

    if 'name' = any(cols) then sets := sets || format('%I = %L', 'name', '탈퇴한 사용자'); end if;
    if 'status' = any(cols) then sets := sets || format('%I = %L', 'status', 'removed'); end if;

    if array_length(sets, 1) > 0 then
      execute format('update public.members set %s where id = $1',
                     array_to_string(sets, ', ')) using uid;
    end if;
    removed := removed || jsonb_build_object('members', 'anonymized');
  else
    removed := removed || jsonb_build_object('members', 'deleted');
  end if;

  return jsonb_build_object('ok', true, 'user_id', uid, 'removed', removed);
end
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

comment on function public.delete_my_account() is
  '본인 계정 삭제. 개인 기록은 삭제하고, 공동체 보존 기록이 참조하면 members 행은 익명화한다.';

NOTIFY pgrst, 'reload schema';
