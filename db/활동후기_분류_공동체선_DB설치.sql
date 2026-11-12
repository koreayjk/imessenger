-- ══════════════════════════════════════════════════════════════
--  활동후기 분류 — 공동체 선 긋기 (구멍 막기)
-- ══════════════════════════════════════════════════════════════
--
--  ⚠️ 운영 DB 에서 재서 찾은 구멍입니다.
--
--  review_cat_write 는 **역할만 보고 공동체를 보지 않습니다.**
--      exists (select 1 from members me
--               where me.id = auth.uid()
--                 and me.community_role in ('super_admin','vice_admin',
--                     'community_admin','admin_officer','teacher','staff'))
--  어느 공동체 소속인지가 식에 아예 없습니다. 실제로 흉내 내 보니
--  한 공동체의 간사가 **남의 공동체 분류를** 마음대로 다룰 수 있었습니다.
--      ① 남의 공동체 분류 고치기 : ❌ 고쳐졌다 (1줄)
--      ② 남의 공동체 분류 지우기 : ❌ 지워졌다 (1줄)
--      ③ 남의 공동체에 분류 넣기 : ❌ 들어갔다
--  (시험은 되돌리는 트랜잭션 안에서 했고, 운영 자료는 그대로입니다.)
--
--  막는 방법 : 넓은 정책(review_cat_read · review_cat_write) 은 그대로 두고,
--  **이름이 다른 restrictive 정책** 을 덧댑니다. permissive 정책은 같은
--  이름으로 다시 깔리면 통째로 덮어써지지만(학생기록_독후감_활동후기_DB설치.sql
--  이 drop 하고 다시 만듭니다), restrictive 는 and 로 묶이므로 선이 풀리지 않습니다.
--
--  그은 선
--   · 보기   : 우리 공동체 것만 (총·부총관리자는 넘나들 수 있습니다)
--   · 고치기 : 우리 공동체의 간사 이상만
-- ══════════════════════════════════════════════════════════════

--  (주간기록·시간표 설치 파일에도 똑같이 들어 있습니다. 순서는 상관없습니다.)
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
  have text[] := array(select polname::text from pg_policy
                        where polrelid = 'public.review_categories'::regclass);
begin
  if not ('review_cat_comm_line_sel' = any(have)) then
    create policy review_cat_comm_line_sel on public.review_categories
      as restrictive for select to authenticated
      using (public.mine_comm(community_id));
  end if;
  if not ('review_cat_comm_line_ins' = any(have)) then
    create policy review_cat_comm_line_ins on public.review_categories
      as restrictive for insert to authenticated
      with check (public.is_staff_of(community_id));
  end if;
  if not ('review_cat_comm_line_upd' = any(have)) then
    create policy review_cat_comm_line_upd on public.review_categories
      as restrictive for update to authenticated
      using (public.is_staff_of(community_id))
      with check (public.is_staff_of(community_id));
  end if;
  if not ('review_cat_comm_line_del' = any(have)) then
    create policy review_cat_comm_line_del on public.review_categories
      as restrictive for delete to authenticated
      using (public.is_staff_of(community_id));
  end if;
end $$;

revoke truncate on public.review_categories from anon, authenticated;
