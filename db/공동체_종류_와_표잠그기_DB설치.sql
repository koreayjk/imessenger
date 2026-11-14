-- ═══════════════════════════════════════════════════════════════════
--  공동체 — ① 표 잠그기(먼저!)  ② 2종류로 묶기
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  ⚠️ ① 이 먼저인 이유 — 재서 알았습니다.
--
--  public.communities 는 RLS 가 꺼져 있고, anon(로그인 안 한 사람) 과
--  authenticated 에 UPDATE·INSERT·DELETE·TRUNCATE 가 전부 열려 있었습니다.
--  실제로 재 봤습니다 (전부 롤백했습니다):
--
--    · 로그인조차 안 한 사람  → 아무 공동체의 자료실 폴더 ID 바꾸기 = 1건 ✔
--    · 로그인조차 안 한 사람  → 공동체 만들기                      = 1건 ✔
--    · 학생                   → 공동체 이름 바꾸기                 = 1건 ✔
--    · 학생                   → 저장용량 0 으로 만들기             = 1건 ✔
--    · 학생                   → 멤버 없는 공동체 지우기            = 1건 ✔
--
--  자료실 폴더 ID 를 남이 바꿀 수 있으면, 방금 고친 자료실 사고를
--  손으로 다시 일으킬 수 있습니다. 그래서 종류 칸을 붙이기 전에 막습니다.
--
--  ② 종류: 'community' = 리뉴젠 공동체 · 'academy' = 리뉴젠 아카데미
--          · 'overseas' = 해외 그룹 (IM USA · IMOHP)
--     전부 'community' 로 시작하고, 총관리자가 하나씩 아카데미로 옮깁니다.
--     종류는 총관리자만 바꿉니다 (공동체 관리자는 못 바꿉니다).
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
--  1. 종류 칸
-- ─────────────────────────────────────────────────────────────────
alter table public.communities
  add column if not exists kind text not null default 'community';

alter table public.communities drop constraint if exists communities_kind_chk;
alter table public.communities
  add constraint communities_kind_chk check (kind in ('community','academy','overseas'));

comment on column public.communities.kind is
  '공동체 종류. community = 리뉴젠 공동체 · academy = 리뉴젠 아카데미 · overseas = 해외 그룹. 총관리자만 바꿉니다.';

-- ─────────────────────────────────────────────────────────────────
--  2. 거드는 함수
-- ─────────────────────────────────────────────────────────────────

--  그 공동체의 '지금 종류'. 바뀌었는지 견주는 데 씁니다.
create or replace function public.community_kind_of(p_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select c.kind from public.communities c where c.id = p_id;
$$;

--  공동체 설정을 고칠 수 있는 사람
--    · 총관리자          → 어느 공동체든
--    · 부총관리자        → 자기 소속만 (다른 공동체는 눈으로만)
--    · 공동체 관리자     → 자기 소속만
create or replace function public.can_edit_community(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and coalesce(me.status,'active') <> 'removed'
       and ( me.community_role = 'super_admin'
          or ( me.community_id = p_id
               and me.community_role in ('vice_admin','community_admin') ) ));
$$;

grant execute on function public.community_kind_of(uuid) to authenticated;
grant execute on function public.can_edit_community(uuid)  to authenticated;

-- ─────────────────────────────────────────────────────────────────
--  3. 표 잠그기
-- ─────────────────────────────────────────────────────────────────
alter table public.communities enable row level security;

--  보기: 가입 화면이 '로그인 전'에 공동체 목록을 읽어야 하므로 anon 도 봅니다.
--  (가입 드롭다운에 쓰는 이름·설명·색이라 가려야 할 것이 아닙니다)
drop policy if exists communities_select on public.communities;
create policy communities_select on public.communities
  for select to anon, authenticated
  using (true);

--  만들기: 총관리자만
drop policy if exists communities_insert on public.communities;
create policy communities_insert on public.communities
  for insert to authenticated
  with check ((select public.is_super_admin()));

--  고치기: 총관리자 / 자기 공동체의 부총관리자·공동체 관리자
drop policy if exists communities_update on public.communities;
create policy communities_update on public.communities
  for update to authenticated
  using      (public.can_edit_community(id))
  with check (public.can_edit_community(id));

--  지우기: 총관리자만 (멤버가 남아 있으면 FK 가 또 막아줍니다)
drop policy if exists communities_delete on public.communities;
create policy communities_delete on public.communities
  for delete to authenticated
  using ((select public.is_super_admin()));

--  종류는 총관리자만. RESTRICTIVE 라서 위 정책들과 'AND' 로 걸립니다.
--  ⚠️ 이름을 따로 둡니다. 같은 이름이면 나중 설치 파일이 통째로 덮어씁니다
--     (부총관리자 권한에서 세 번 데인 자리입니다).
drop policy if exists communities_kind_super_only on public.communities;
create policy communities_kind_super_only on public.communities
  as restrictive for update to authenticated
  using (true)
  with check (
    (select public.is_super_admin())
    or kind is not distinct from public.community_kind_of(id)
  );

--  TRUNCATE 는 RLS 가 막지 못합니다. 권한 자체를 거둡니다.
revoke truncate on public.communities from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────
--  4. 확인
-- ─────────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from pg_policies
   where schemaname='public' and tablename='communities';
  raise notice '공동체 표 정책 %개 (5개여야 합니다)', n;
  if not (select relrowsecurity from pg_class
           where relname='communities' and relnamespace='public'::regnamespace) then
    raise exception 'RLS 가 켜지지 않았습니다';
  end if;
end $$;
