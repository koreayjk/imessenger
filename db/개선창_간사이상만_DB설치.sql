-- ═══════════════════════════════════════════════════════════════════
--  💡 개선창 — 간사 이상만 보고 쓰게
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  2026-11-25 선교사님 지시:
--    「개선창 이제 학생들에게는 안보이게 해줘.
--      간사 이상급만보이고 작성할수있게 해줘 이제부터는」
--
--  전에는 improvements / improvement_comments 의 읽기 규칙이
--      using (true)
--  였습니다. 로그인한 사람이면 **학생·학부모까지 전부** 보았습니다.
--  쓰기는 author_id = auth.uid() 하나뿐이어서 역할을 안 봤습니다.
--
--  간사 이상 판정은 이미 있는 is_school_staff() 를 그대로 씁니다
--  (총관리자·부총관리자·관리자·행정담당자·교사·간사).
--  판정을 두 군데 따로 두면 언젠가 어긋나므로 새로 만들지 않습니다.
--
--  ⚠️ 화면만 가려서는 안 됩니다. 화면을 거치지 않고 부르면 그대로
--     열리기 때문입니다. 그래서 표의 규칙을 같이 좁힙니다.
--
--  ⚠️ drop 대신 alter policy 를 씁니다 — 이 저장소의 약속입니다
--     (drop 이 들어간 문장은 확인 창에 걸려 아무것도 적용되지 않습니다).
--
--  넣고 나면 —
--   · 학생·학부모 : 개선창 글이 한 줄도 안 읽힙니다. 쓰기도 막힙니다.
--   · 간사 이상    : 전과 똑같습니다 (지난 글도 다 보입니다).
--   · 이미 올라온 글은 지우지 않습니다 — 그냥 안 보이게만 됩니다.
-- ═══════════════════════════════════════════════════════════════════

--  ── 글 ──
alter policy improvements_select on public.improvements
  using (public.is_school_staff());

alter policy improvements_insert on public.improvements
  with check (author_id = auth.uid() and public.is_school_staff());

--  ── 댓글 ──
alter policy impcomments_select on public.improvement_comments
  using (public.is_school_staff());

alter policy impcomments_insert on public.improvement_comments
  with check (author_id = auth.uid() and public.is_school_staff());

--  제대로 좁혀졌는지 확인
do $$
declare n int;
begin
  select count(*) into n
    from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relname in ('improvements','improvement_comments')
     and p.polname in ('improvements_select','improvements_insert',
                       'impcomments_select','impcomments_insert')
     and coalesce(pg_get_expr(p.polqual, p.polrelid), '')
       || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') like '%is_school_staff%';
  if n <> 4 then raise exception '규칙 4개가 아닙니다 (%개)', n; end if;
  raise notice '개선창 간사 이상만 — 설치 완료';
end $$;
