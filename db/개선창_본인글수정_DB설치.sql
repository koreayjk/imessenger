-- =====================================================================
--  ✏️ 개선창 — 본인이 올린 글 고치기
--
--  지금은 올린 사람도 자기 글을 못 고칩니다. 지우고 다시 올리는 수밖에
--  없는데, 그러면 달려 있던 댓글과 처리 상태가 같이 사라집니다.
--
--  이 파일은 '글쓴이가 자기 글의 제목·내용을 고칠 수 있게' 열어 줍니다.
--  처리 상태(검토중·반영됨 등)는 그대로 관리자만 바꿉니다 —
--  본인이 자기 글을 '반영됨'으로 바꿔 버리면 안 되니까요.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.improvements
  add column if not exists updated_at timestamptz;

comment on column public.improvements.updated_at is '고친 시각. 비어 있으면 한 번도 안 고친 글';

-- 고치기 전 값을 읽는 도우미.
-- stable 이라 UPDATE 도중에 불러도 '바뀌기 전' 값을 돌려준다 —
-- 글쓴이가 상태까지 몰래 바꾸는지 가려내는 데 이 성질을 쓴다.
create or replace function public.improve_status_of(target uuid)
returns text language sql security definer stable set search_path = public as $$
  select status from public.improvements where id = target;
$$;
grant execute on function public.improve_status_of(uuid) to authenticated;

drop policy if exists improvements_update on public.improvements;
create policy improvements_update on public.improvements
  for update to authenticated
  using ( public.is_improve_admin() or author_id = auth.uid() )
  with check (
    public.is_improve_admin()
    -- 글쓴이는 자기 글만, 그리고 상태는 건드리지 않는 선에서
    or ( author_id = auth.uid()
         and status is not distinct from public.improve_status_of(id) )
  );

notify pgrst, 'reload schema';

-- ── 확인 ──
select polname as "정책",
       case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                   when 'w' then 'UPDATE' when 'd' then 'DELETE' else 'ALL' end as "대상"
  from pg_policy where polrelid = 'public.improvements'::regclass order by 2,1;

-- =====================================================================
--  개선창에서 내가 올린 글에 ✏️ 가 생깁니다.
--  고치면 날짜 옆에 '수정됨'이 붙습니다.
-- =====================================================================
