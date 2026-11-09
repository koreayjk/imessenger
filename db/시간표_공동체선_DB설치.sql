-- ══════════════════════════════════════════════════════════════
--  시간표 — 공동체 선 긋기 (구멍 막기)
-- ══════════════════════════════════════════════════════════════
--
--  ⚠️ 운영 DB 에서 재서 찾은 구멍입니다.
--
--  timetables 의 정책이 `for all using (true) with check (true)` 였습니다.
--  공동체도, 역할도 보지 않습니다. 실제로 흉내 내 보니 **학생 한 명이
--  남의 공동체 시간표를 고치고 지울 수 있었습니다**(각각 1줄).
--     ① 학생이 남의 공동체 시간표 고치기 : ❌ 고쳐졌다 (1줄)
--     ② 학생이 남의 공동체 시간표 지우기 : ❌ 지워졌다 (1줄)
--  (시험은 되돌리는 트랜잭션 안에서 했고, 운영 자료는 그대로입니다.)
--
--  막는 방법 : 넓은 정책(timetables_rw) 은 그대로 두고, **이름이 다른
--  restrictive 정책** 을 덧댑니다. permissive 정책은 같은 이름으로
--  다시 깔리면 통째로 덮어써지지만, restrictive 는 and 로 묶이므로
--  나중에 어떤 설치 파일이 또 와도 선이 풀리지 않습니다.
--
--  그은 선
--   · 보기   : 우리 공동체 것만 (총·부총관리자는 넘나들 수 있습니다)
--   · 고치기 : 간사 이상만 — 화면의 '학사관리' 메뉴와 같은 선입니다
-- ══════════════════════════════════════════════════════════════

--  (주간기록_DB설치.sql 에도 똑같이 들어 있습니다. 어느 쪽을 먼저 깔아도 됩니다.)
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

--  이미 있으면 넘어갑니다 — 두 번 깔아도 터지지 않습니다.
do $$
declare
  have text[] := array(select polname::text from pg_policy where polrelid = 'public.timetables'::regclass);
begin
  if not ('timetables_comm_line_sel' = any(have)) then
    create policy timetables_comm_line_sel on public.timetables
      as restrictive for select to authenticated
      using (public.mine_comm(community_id));
  end if;
  if not ('timetables_comm_line_ins' = any(have)) then
    create policy timetables_comm_line_ins on public.timetables
      as restrictive for insert to authenticated
      with check (public.is_staff_of(community_id));
  end if;
  if not ('timetables_comm_line_upd' = any(have)) then
    create policy timetables_comm_line_upd on public.timetables
      as restrictive for update to authenticated
      using (public.is_staff_of(community_id))
      with check (public.is_staff_of(community_id));
  end if;
  if not ('timetables_comm_line_del' = any(have)) then
    create policy timetables_comm_line_del on public.timetables
      as restrictive for delete to authenticated
      using (public.is_staff_of(community_id));
  end if;
end $$;

revoke truncate on public.timetables from anon, authenticated;
