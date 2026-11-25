-- ═══════════════════════════════════════════════════════════════════
--  🗓 개인 시간표 — 선생님도 아이 것을 짤 수 있게
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  개선창 · 홍예원 (IM HQ, 11/20):
--    「공통일정 말고 개인 일정으로 설정할 수 있었으면 좋겠습니다!
--      생기부 >> 시간표 / 이 부분은 다 공통이더라구요ㅠㅜ」
--
--  개인 시간표(student_timetables)는 이미 있었습니다. 그런데 쓰기 규칙이
--      member_id = auth.uid()
--  하나뿐이어서 **학생 본인만** 짤 수 있고, 선생님은 생기부에서 보기만
--  했습니다. 아이가 안 짜면 선생님이 할 수 있는 일이 없었습니다.
--
--  그래서 교직원(간사 이상)도 쓸 수 있게 넓힙니다.
--
--  ⚠️ is_school_staff() 만으로 넓히면 안 됩니다. 그 함수는 공동체를
--     보지 않아서, 다른 공동체 선생님이 우리 아이 시간표를 고칠 수 있게
--     됩니다. **그 아이가 내 공동체 아이인지**를 같이 봅니다.
--
--  넣고 나면 —
--   · 학생      : 전과 똑같이 자기 것을 짭니다
--   · 간사 이상 : 같은 공동체 아이 것을 짜고 고치고 지울 수 있습니다
--   · 남의 공동체 아이 : 못 건드립니다
-- ═══════════════════════════════════════════════════════════════════

--  내 공동체 아이인가 (규칙 안에서 쓰려고 따로 둡니다 — 세 군데에 같은
--  글을 세 번 적으면 한 군데만 고치는 실수가 생깁니다)
create or replace function public.stt_can_write(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target = auth.uid()
      or ( public.is_school_staff()
           and exists ( select 1 from public.members s
                         where s.id = target
                           and s.community_id = public.my_community_id() ) );
$$;

--  ⚠️ drop 대신 alter policy 를 씁니다 — 이 저장소의 약속입니다.
alter policy stt_insert on public.student_timetables
  with check (public.stt_can_write(member_id));

alter policy stt_update on public.student_timetables
  using (public.stt_can_write(member_id));

alter policy stt_delete on public.student_timetables
  using (public.stt_can_write(member_id));

--  제대로 좁혀졌는지 확인
do $$
declare n int;
begin
  select count(*) into n
    from pg_policy p
   where p.polrelid = 'public.student_timetables'::regclass
     and p.polname in ('stt_insert','stt_update','stt_delete')
     and coalesce(pg_get_expr(p.polqual, p.polrelid), '')
       || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') like '%stt_can_write%';
  if n <> 3 then raise exception '규칙 3개가 아닙니다 (%개)', n; end if;
  raise notice '개인 시간표 선생님도 쓰기 — 설치 완료';
end $$;
