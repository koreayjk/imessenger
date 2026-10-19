-- ════════════════════════════════════════════════════════════════════
--  🗓 개인 일정
--
--  "일정에서 지금은 전체 일정을 올리는 거잖아. 이걸 개인 일정도
--   올릴 수 있게 해줘. 일정을 올릴 때 공동체 일정인지 개인 일정인지를
--   선택할 수 있게, 기본값은 개인 일정으로 해주고"
--
--  events 에 owner_id 를 둡니다.
--    owner_id 가 비어 있으면  → 공동체 일정 (예전 것 전부)
--    owner_id 가 내 id 면      → 내 일정. 나만 봅니다.
--
--  새 칸이라 지금 있는 일정은 전부 owner_id 가 비어 있고, 그대로
--  공동체 일정로 남습니다. 아무것도 사라지지 않습니다.
--
--  ⚠️ 개인 일정은 '남이 못 보는' 것이 요점입니다. 화면에서만 가리면
--     주소만 알면 남의 일정을 읽을 수 있습니다. 서버에서 막습니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

alter table public.events
  add column if not exists owner_id uuid;

create index if not exists events_owner_idx on public.events (owner_id);

-- ── 보기 ──
--  공동체 일정은 그 공동체 사람에게, 개인 일정은 본인에게만.
drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select to authenticated
  using (
    ( owner_id is null and public.mine_comm(community_id) )
    or owner_id = auth.uid()
  );

-- ── 만들기 ──
--  내 일정은 누구나. 공동체 일정은 예전 규칙(교직원) 그대로.
drop policy if exists events_insert on public.events;
create policy events_insert on public.events
  for insert to authenticated
  with check (
    ( owner_id = auth.uid() and public.mine_comm(community_id) )
    or ( owner_id is null and public.staff_of(community_id) )
  );

-- ── 고치기·지우기 ──
--  내 일정은 나만. 공동체 일정은 교직원.
drop policy if exists events_update on public.events;
create policy events_update on public.events
  for update to authenticated
  using      ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) )
  with check ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) );

drop policy if exists events_delete on public.events;
create policy events_delete on public.events
  for delete to authenticated
  using ( owner_id = auth.uid() or ( owner_id is null and public.staff_of(community_id) ) );

alter table public.events enable row level security;
grant select, insert, update, delete on public.events to authenticated;

notify pgrst, 'reload schema';

select '설치 끝 — 이제 개인 일정을 올릴 수 있어요 (나만 봅니다)' as "결과";
