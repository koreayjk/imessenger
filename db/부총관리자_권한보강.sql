-- =====================================================================
--  🔧 부총관리자 — 빠져 있던 권한 채우기
--
--  무엇이 문제였나
--   부총관리자를 만들면서 members 표의 정책은 손봤지만, 다른 표들은
--   그대로 뒀습니다. 그 표들의 정책 안에는 '관리자·행정담당자·교사…'
--   처럼 역할 이름이 줄줄이 적혀 있는데, 거기 부총관리자가 없습니다.
--   그래서 화면은 열리는데 저장을 누르면 이렇게 튕깁니다.
--
--     new row violates row-level security policy for table "org_seals"
--
--   직인·증명서뿐 아니라 재정·학사·매점·결재도 같은 상태입니다.
--
--  이 파일이 하는 일
--   역할 목록이 적힌 정책과 함수를 모두 찾아 'vice_admin'(부총관리자)을
--   끼워 넣습니다. 파일에 적힌 모양이 아니라 '지금 DB 에 실제로 들어
--   있는 내용'을 읽어서 고치므로, 그동안 손으로 바꾼 것이 있어도 안전합니다.
--
--   공동체 범위는 건드리지 않습니다. 원래 정책이 '내 공동체일 때만'
--   이라고 되어 있으면 부총관리자도 자기 공동체에서만 쓸 수 있습니다.
--   남의 공동체는 그대로 못 고칩니다.
--
--  건드리지 않는 것
--   · members 표의 정책 — 부총관리자_DB설치.sql 에서 일부러 그렇게 짰습니다
--   · is_super_admin / can_admin_members / is_improve_admin
--     — 총관리자만 할 일이라 일부러 빼 둔 자리입니다
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================


-- ── 1. 역할 목록에 부총관리자를 끼워 넣는 도우미 ──
--  정책은 ARRAY['a'::text, 'b'::text] 모양으로, 함수는 원본 그대로
--  in ('a','b') 모양으로 저장됩니다. 두 모양을 다 다룹니다.
--  '= 관리자' 같은 등호 비교에는 손대지 않습니다 (콤마를 넣으면 깨지므로
--  반드시 목록 안일 때만 바꿉니다).
create or replace function public._tcs_add_vice(src text, mode text)
returns text language plpgsql immutable as $fn$
declare s text := src;
begin
  if s is null then return null; end if;
  if position('vice_admin' in s) > 0 and position('부총관리자' in s) > 0 then return s; end if;

  if mode = 'policy' then
    -- 정책은 ARRAY['a'::text, 'b'::text] 로 정규화되어 저장된다
    s := replace(s, 'ARRAY[''community_admin''::text', 'ARRAY[''vice_admin''::text, ''community_admin''::text');
    s := replace(s, ', ''community_admin''::text',     ', ''vice_admin''::text, ''community_admin''::text');
    s := replace(s, 'ARRAY[''관리자''::text',           'ARRAY[''부총관리자''::text, ''관리자''::text');
    s := replace(s, ', ''관리자''::text',               ', ''부총관리자''::text, ''관리자''::text');
  else
    -- 함수는 쓴 그대로 in ('a','b') 모양으로 저장된다
    s := replace(s, '(''community_admin''',  '(''vice_admin'',''community_admin''');
    s := replace(s, ',''community_admin''',  ',''vice_admin'',''community_admin''');
    s := replace(s, ', ''community_admin''', ', ''vice_admin'', ''community_admin''');
    s := replace(s, '(''관리자''',            '(''부총관리자'',''관리자''');
    s := replace(s, ',''관리자''',            ',''부총관리자'',''관리자''');
    s := replace(s, ', ''관리자''',           ', ''부총관리자'', ''관리자''');
  end if;

  -- 규칙이 겹쳐 두 번 끼어들었으면 정리 (재실행해도 안전하게)
  s := replace(s, '''vice_admin''::text, ''vice_admin''::text', '''vice_admin''::text');
  s := replace(s, '''vice_admin'', ''vice_admin''',             '''vice_admin''');
  s := replace(s, '''vice_admin'',''vice_admin''',              '''vice_admin''');
  s := replace(s, '''부총관리자''::text, ''부총관리자''::text',  '''부총관리자''::text');
  s := replace(s, '''부총관리자'', ''부총관리자''',              '''부총관리자''');
  s := replace(s, '''부총관리자'',''부총관리자''',               '''부총관리자''');
  return s;
end $fn$;


-- ── 2. 함수 고치기 ──
-- psql/SQL 편집기는 문장마다 트랜잭션이 끝나므로 on commit drop 을 쓰면 안 된다
drop table if exists _tcs_log;
create temp table _tcs_log (kind text, name text, result text);

do $$
declare r record; def text; newdef text;
begin
  for r in
    select p.oid, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname not in ('is_super_admin','can_admin_members','can_view_all_communities',
                             'is_vice_admin','is_improve_admin','member_role_of','member_status_of',
                             'my_community_id','_tcs_add_vice')
       and (p.prosrc like '%community_admin%' or p.prosrc like '%관리자%')
       and p.prosrc not like '%vice_admin%'
  loop
    def := pg_get_functiondef(r.oid);
    newdef := public._tcs_add_vice(def, 'func');
    if newdef is distinct from def then
      begin
        execute newdef;
        insert into _tcs_log values ('함수', r.proname, '부총관리자 추가됨');
      exception when others then
        insert into _tcs_log values ('함수', r.proname, '건너뜀 — ' || sqlerrm);
      end;
    else
      insert into _tcs_log values ('함수', r.proname, '⚠️ 손 못 댐 — 역할 목록 모양이 다릅니다');
    end if;
  end loop;
end $$;


-- ── 3. 정책 고치기 ──
--  members 표는 손대지 않는다 (부총관리자_DB설치.sql 에서 따로 짜 둔 것)
do $$
declare r record; q text; w text; stmt text; cmd text; roles text;
begin
  for r in
    select p.polname, p.polrelid, c.relname,
           (p.polrelid::regclass)::text as tbl, p.polcmd, p.polpermissive,
           pg_get_expr(p.polqual, p.polrelid)      as qual,
           pg_get_expr(p.polwithcheck, p.polrelid) as chk,
           array(select quote_ident(rolname) from pg_roles where oid = any(p.polroles)) as rls
      from pg_policy p
      join pg_class c on c.oid = p.polrelid
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relname <> 'members'
       and (coalesce(pg_get_expr(p.polqual, p.polrelid), '') like '%community_admin%'
         or coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') like '%community_admin%'
         or coalesce(pg_get_expr(p.polqual, p.polrelid), '') like '%관리자%'
         or coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') like '%관리자%')
       and coalesce(pg_get_expr(p.polqual, p.polrelid), '')      not like '%vice_admin%'
       and coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') not like '%vice_admin%'
  loop
    q := public._tcs_add_vice(r.qual, 'policy');
    w := public._tcs_add_vice(r.chk, 'policy');
    if q is not distinct from r.qual and w is not distinct from r.chk then
      insert into _tcs_log values ('정책', r.tbl || ' · ' || r.polname, '⚠️ 손 못 댐 — 역할 목록 모양이 다릅니다');
      continue;
    end if;

    cmd := case r.polcmd when 'r' then 'select' when 'a' then 'insert'
                         when 'w' then 'update' when 'd' then 'delete' else 'all' end;
    roles := case when array_length(r.rls,1) is null then 'public'
                  else array_to_string(r.rls, ', ') end;
    stmt := format('create policy %I on %s as %s for %s to %s',
                   r.polname, r.tbl,
                   case when r.polpermissive then 'permissive' else 'restrictive' end,
                   cmd, roles);
    if q is not null then stmt := stmt || format(' using (%s)', q); end if;
    if w is not null then stmt := stmt || format(' with check (%s)', w); end if;

    begin
      execute format('drop policy %I on %s', r.polname, r.tbl);
      execute stmt;
      insert into _tcs_log values ('정책', r.tbl || ' · ' || r.polname, '부총관리자 추가됨');
    exception when others then
      insert into _tcs_log values ('정책', r.tbl || ' · ' || r.polname, '⚠️ 실패 — ' || sqlerrm);
    end;
  end loop;
end $$;

notify pgrst, 'reload schema';


-- ── 4. 무엇이 바뀌었나 ──
select kind as "종류", name as "이름", result as "결과"
  from _tcs_log
 order by case when result like '⚠️%' then 0 else 1 end, 1, 2;

-- ⚠️ '결과'에 ⚠️ 가 하나라도 있으면 그 줄을 그대로 알려주세요.
--    자동으로 못 고친 자리라, 모양을 보고 따로 손봐 드리겠습니다.
--    (한 줄도 없으면 전부 깔끔하게 들어간 것입니다)

drop function if exists public._tcs_add_vice(text, text);
drop table if exists _tcs_log;

-- =====================================================================
--  이 뒤로 부총관리자는 '자기 소속 공동체에서' 관리자와 똑같이
--  직인·증명서·재정·학사·매점·결재를 쓸 수 있습니다.
--  남의 공동체는 여전히 보기와 채팅만 됩니다.
-- =====================================================================
