-- =====================================================================
--  🙏 기도제목 지우기
--
--  지금은 한 번 올린 기도제목을 지울 수가 없습니다. 오타가 나거나
--  응답받은 제목을 내리고 싶어도 방법이 없습니다.
--  올린 사람과 공동체 관리자가 지울 수 있게 합니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.prayers enable row level security;

-- 보기·올리기는 하던 대로 (RLS 를 켜면 허용 정책이 없을 때 전부 막히므로
-- 여기서 같이 깔아 둔다)
drop policy if exists prayers_select on public.prayers;
create policy prayers_select on public.prayers for select to authenticated
  using ( community_id = public.my_community_id() or public.can_view_all_communities() );

drop policy if exists prayers_insert on public.prayers;
create policy prayers_insert on public.prayers for insert to authenticated
  with check ( member_id = auth.uid() and community_id = public.my_community_id() );

-- '함께 기도' 숫자는 누구나 올릴 수 있어야 한다
drop policy if exists prayers_update on public.prayers;
create policy prayers_update on public.prayers for update to authenticated
  using ( community_id = public.my_community_id() )
  with check ( community_id = public.my_community_id() );

-- 지우기: 올린 사람과 관리자
drop policy if exists prayers_delete on public.prayers;
create policy prayers_delete on public.prayers for delete to authenticated
  using (
    member_id = auth.uid()
    or public.can_admin_members()
    or (public.is_vice_admin() and community_id = public.my_community_id())
  );

grant select, insert, update, delete on public.prayers to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ──
select polname as "정책",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end as "대상"
  from pg_policy where polrelid = 'public.prayers'::regclass order by 2,1;

-- =====================================================================
--  ❗ 혹시 기도제목이 안 보이거나 안 올라가면 이 한 줄로 되돌립니다:
--       alter table public.prayers disable row level security;
--     그리고 어디가 막혔는지 알려주세요.
-- =====================================================================
