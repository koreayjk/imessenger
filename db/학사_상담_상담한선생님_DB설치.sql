-- ═══════════════════════════════════════════════════════════════════
--  💬 상담기록 — 「상담한 선생님」 칸 붙이기
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  개선창 · Clara (IM HQ, 11/13):
--    「[학사] >> [상담기록]에 추가했으면 하는게 있습니다 !!
--      상담을 어느 선생님이 했는지 선택하는 란이 있으면 좋겠습니다.
--      선생님 이름이 다 나와서 누가 했는지를 클릭하게요 !」
--
--  지금 상담기록에는 author_name(적은 사람) 만 있습니다. 적은 사람과
--  **상담한 사람이 다를 수 있습니다** — 간사가 선생님 상담을 대신
--  적어 넣는 일이 있기 때문입니다. 그래서 author_name 을 덮어쓰지 않고
--  칸을 따로 둡니다. 적은 사람은 적은 사람으로 남습니다.
-- ═══════════════════════════════════════════════════════════════════

alter table public.counseling_logs add column if not exists counselor_id   uuid;
alter table public.counseling_logs add column if not exists counselor_name text;

--  제대로 붙었는지 확인
do $$
declare n int;
begin
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'counseling_logs'
     and column_name in ('counselor_id','counselor_name');
  if n <> 2 then raise exception '칸이 안 붙었습니다 (%개)', n; end if;
  raise notice '상담한 선생님 칸 — 설치 완료';
end $$;
