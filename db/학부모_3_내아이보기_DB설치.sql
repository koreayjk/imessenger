-- =====================================================================
--  👀 3단계 — 학부모가 '내 아이' 를 볼 수 있게
--
--  여는 것은 세 가지뿐입니다.
--    🏦 예치금  — 잔액과 입출금 내역
--    🏪 매점    — 무엇을 사 먹었는지
--    💰 학비    — 고지와 납입 (1단계에서 이미 열렸습니다)
--
--  생활기록부·출결·보건·상담은 그대로 닫혀 있습니다.
--  보기만 됩니다. 학부모는 아무것도 고치지 못합니다.
--
--  ※ 1단계(칸막이)를 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regprocedure('public.my_children()') is null then
    raise exception '먼저 db/학부모_1_칸막이_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- ── 0. 담임인가 ──────────────────────────────────────────────────
--  지금 정책은 members·student_homerooms 를 정책 안에서 직접 읽습니다.
--  읽을 권한이 없는 사람(앞으로 들어올 학부모 같은)에게는 그 자체가
--  오류가 됩니다. 함수로 감싸 두면 그런 일이 없습니다.
create or replace function public.is_homeroom_of(sid uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.members s
                  where s.id = sid and s.homeroom_teacher_id = auth.uid())
      or exists (select 1 from public.student_homerooms h
                  where h.student_id = sid and h.teacher_id = auth.uid());
$$;

-- ── 1. 예치금 — 본인 + 담임 + 우리 공동체 교직원 + 그 아이의 부모 ──
--  덤으로 하나 막습니다. 지금 정책은 '교직원이면' 통과라서 공동체를
--  따지지 않습니다. 남의 공동체 교사도 우리 학생들 예치금·용돈 내역이
--  전부 읽혔습니다. staff_of(community_id) 로 바꿔 우리 공동체로 가둡니다.
drop policy if exists deposit_select on public.deposit_entries;
create policy deposit_select on public.deposit_entries for select to authenticated
using (
  member_id = auth.uid()
  or member_id in (select public.my_children())
  or public.is_homeroom_of(member_id)
  or public.staff_of(community_id)
);

-- 용돈기입장도 같은 구멍이 있습니다. 학부모에게는 열지 않고, 새는 것만 막습니다.
drop policy if exists allowance_select on public.allowance_entries;
create policy allowance_select on public.allowance_entries for select to authenticated
using (
  member_id = auth.uid()
  or public.is_homeroom_of(member_id)
  or public.staff_of(community_id)
);
--  넣고 고치고 지우는 정책은 건드리지 않습니다 — 학부모는 보기만 합니다.

-- ── 2. 매점 — 산 사람 본인과 그 아이의 부모도 볼 수 있게 ────────────
--  지금은 교직원만 볼 수 있어서, 학생도 자기가 뭘 샀는지 못 봤습니다.
drop policy if exists store_sales_read on public.store_sales;
create policy store_sales_read on public.store_sales for select to authenticated
using (
  public.store_can_read(community_id)
  or member_id = auth.uid()
  or member_id in (select public.my_children())
);

drop policy if exists store_sale_items_read on public.store_sale_items;
create policy store_sale_items_read on public.store_sale_items for select to authenticated
using (exists (
  select 1 from public.store_sales s
   where s.id = store_sale_items.sale_id
     and ( public.store_can_read(s.community_id)
        or s.member_id = auth.uid()
        or s.member_id in (select public.my_children()) )
));

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select tablename as "표", policyname as "정책"
  from pg_policies
 where schemaname = 'public'
   and tablename in ('deposit_entries','store_sales','store_sale_items','tuition_bills')
   and cmd in ('SELECT','ALL')
 order by 1, 2;

-- =====================================================================
--  이걸 실행하면 학부모 화면의 '내 아이' 에 예치금·매점·학비가 채워집니다.
--  실행 전에는 비어 있을 뿐, 아무것도 깨지지 않습니다.
-- =====================================================================
