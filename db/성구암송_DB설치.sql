-- =====================================================================
--  📜 성구암송 — 60구절 · 소교리문답
--
--  요청: "학사란 윗 부분에 트리플스쿨 옆에 성구암송 칸을 넣어주시면
--   좋겠습니다. 성구암송 안에서 60구절이랑 소교리문답 체크를 하고
--   싶은데, 이 부분은 어떻게 할 수 있을지요~"
--   + "암송체크는 교사도 체크하게"
--
--  두 단계입니다 — 학생이 '외웠어요' 체크하고, 교사가 '확인' 도장을
--  찍습니다. 교사가 곧바로 둘 다 찍을 수도 있습니다(학생 앞에서
--  듣고 바로 처리할 때).
--
--  ⚠️ '확인' 은 학생이 스스로 찍으면 안 됩니다. 그러면 확인이 아무
--     뜻이 없습니다. 그런데 RLS 로는 '이 칸만 못 고치게' 를 깔끔하게
--     못 막습니다. 그래서 체크/확인을 함수로만 하게 하고, 표에는
--     읽기만 열어 둡니다. 함수 안에서 누가 부른 건지 다시 봅니다.
--
--  ※ db/전체잠그기_RLS.sql 과 db/신고차단_DB설치.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 1. 외울 거리 ────────────────────────────────────────────────
create table if not exists public.memory_items (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('verse','catechism')),
  no           int  not null,            -- 1..60, 1..107
  title        text not null,            -- '요한복음 3:16' | '제1문'
  body         text,                     -- 구절 본문 | 문(질문)
  answer       text,                     -- 소교리문답의 답
  community_id uuid,                     -- 비어 있으면 전 공동체 공통
  sort         int,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);
create unique index if not exists memory_items_uq
  on public.memory_items (kind, no, coalesce(community_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists memory_items_kind_idx on public.memory_items (kind, sort, no);

comment on table public.memory_items is
  '암송 항목. community_id 가 비어 있으면 모든 공동체가 같이 쓴다.';

-- ── 2. 누가 무엇을 외웠나 ───────────────────────────────────────
create table if not exists public.memory_checks (
  id           uuid primary key default gen_random_uuid(),
  item_id      uuid not null references public.memory_items(id) on delete cascade,
  student_id   uuid not null,
  community_id uuid,
  checked_at   timestamptz,      -- 학생이 '외웠어요' 한 때
  confirmed_at timestamptz,      -- 교사가 '확인' 한 때
  confirmed_by uuid,
  updated_at   timestamptz not null default now(),
  unique (item_id, student_id)
);
create index if not exists memory_checks_student_idx on public.memory_checks (student_id);
create index if not exists memory_checks_item_idx    on public.memory_checks (item_id);

-- ── 3. 보는 권한 ────────────────────────────────────────────────
alter table public.memory_items  enable row level security;
alter table public.memory_checks enable row level security;

drop policy if exists memory_items_select on public.memory_items;
create policy memory_items_select on public.memory_items
  for select to authenticated
  using ( community_id is null or public.mine_comm(community_id) );

-- 항목을 더하고 고치는 건 교직원만
drop policy if exists memory_items_write on public.memory_items;
create policy memory_items_write on public.memory_items
  for all to authenticated
  using ( public.staff_of(coalesce(community_id, public.my_community_id())) )
  with check ( public.staff_of(coalesce(community_id, public.my_community_id())) );

-- 내 체크는 내가, 학생 전체는 교직원이 본다
drop policy if exists memory_checks_select on public.memory_checks;
create policy memory_checks_select on public.memory_checks
  for select to authenticated
  using ( student_id = auth.uid() or public.staff_of(community_id) );

-- 쓰기는 아래 함수로만. 표에 직접 쓰는 길은 열지 않는다.
grant select on public.memory_items  to authenticated;
grant select on public.memory_checks to authenticated;
grant insert, update, delete on public.memory_items to authenticated;

-- ── 4. 체크 · 확인 (함수로만) ───────────────────────────────────
--  학생이 '외웠어요' 를 켜고 끈다. 확인 도장은 건드리지 못한다.
create or replace function public.memory_check(p_item uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_cid uuid;
begin
  select community_id into v_cid from public.members where id = auth.uid();
  if v_cid is null then raise exception '로그인이 필요합니다'; end if;

  insert into public.memory_checks (item_id, student_id, community_id, checked_at, updated_at)
  values (p_item, auth.uid(), v_cid, case when p_on then now() else null end, now())
  on conflict (item_id, student_id) do update
    set checked_at = case when p_on then coalesce(public.memory_checks.checked_at, now()) else null end,
        -- 학생이 체크를 풀면 교사 확인도 같이 풀린다. 안 그러면
        -- '학생은 안 외웠다는데 확인은 찍혀 있는' 줄이 남는다.
        confirmed_at = case when p_on then public.memory_checks.confirmed_at else null end,
        confirmed_by = case when p_on then public.memory_checks.confirmed_by else null end,
        updated_at = now();
end $$;
grant execute on function public.memory_check(uuid, boolean) to authenticated;

--  교사가 '확인' 도장을 찍고 뗀다. 학생이 아직 체크 안 했으면
--  체크까지 같이 찍는다 — 교사가 직접 듣고 처리하는 경우다.
create or replace function public.memory_confirm(p_item uuid, p_student uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_cid uuid;
begin
  select community_id into v_cid from public.members where id = p_student;
  if v_cid is null then raise exception '학생을 찾을 수 없습니다'; end if;
  if not public.staff_of(v_cid) then raise exception '확인 권한이 없습니다'; end if;

  insert into public.memory_checks (item_id, student_id, community_id, checked_at, confirmed_at, confirmed_by, updated_at)
  values (p_item, p_student, v_cid,
          case when p_on then now() else null end,
          case when p_on then now() else null end,
          case when p_on then auth.uid() else null end,
          now())
  on conflict (item_id, student_id) do update
    set checked_at   = case when p_on then coalesce(public.memory_checks.checked_at, now()) else public.memory_checks.checked_at end,
        confirmed_at = case when p_on then now() else null end,
        confirmed_by = case when p_on then auth.uid() else null end,
        updated_at = now();
end $$;
grant execute on function public.memory_confirm(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "갈래", count(*) as "항목 수" from public.memory_items group by 1 order by 1;

-- =====================================================================
--  다음: 외울 거리를 넣으세요.
--   · db/성구암송_내용_60구절.sql
--   · db/성구암송_내용_소교리문답.sql
--  둘 다 '선생님이 화면에서 고칠 수 있는' 값입니다. 쓰시는 번역과
--  다르면 학사 → 성구암송 → 항목 관리 에서 통째로 바꿀 수 있습니다.
-- =====================================================================
