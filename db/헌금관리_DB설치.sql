-- =====================================================================
--  🙏 헌금관리 — 예배 때 들어온 헌금(현금·수표 봉투)을 적는 표
--
--  '입출금(ledger)' 과 겹치지 않습니다.
--    · 입출금 = 은행 내역을 불러와 분류하는 것 (계좌를 거친 돈)
--    · 헌금   = 예배 때 봉투로 들어온 것 (계좌를 거치기 전의 돈)
--
--  누가 보나
--    행정담당자 이상만 봅니다 — 총관리자 · 부총관리자 · 관리자 · 행정담당자.
--    교사·간사·학생·학부모는 **목록조차 못 봅니다.** 누가 얼마를 드렸는지는
--    민감한 정보라, 화면에서 버튼만 숨기는 것으로는 모자랍니다.
--
--    · 부총관리자는 다른 공동체 것도 **눈으로만** 봅니다 (적지는 못합니다).
--    · 총관리자만 어느 공동체든 적을 수 있습니다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

create table if not exists public.offerings (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  date         date not null default current_date,
  kind         text not null,                 -- 주일헌금 · 십일조 · 감사헌금 …
  member_id    uuid references public.members(id) on delete set null,
  donor_name   text,                          -- 앱에 없는 분은 이름만 적는다
  amount       numeric(14,2) not null,
  currency     text not null default '원',
  method       text not null default 'cash',  -- cash · check · transfer · card · other
  memo         text,
  created_by   uuid references public.members(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

--  금액은 0 보다 커야 합니다. 빼는 것은 헌금이 아닙니다.
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'offerings_amount_pos') then
    alter table public.offerings add constraint offerings_amount_pos check (amount > 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'offerings_method_ok') then
    alter table public.offerings add constraint offerings_method_ok
      check (method in ('cash','check','transfer','card','other'));
  end if;
end $$;

create index if not exists offerings_comm_date_idx on public.offerings (community_id, date desc);
create index if not exists offerings_member_idx    on public.offerings (member_id);

--  고친 때를 자동으로 남긴다
create or replace function public.offerings_touch() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists offerings_touch_t on public.offerings;
create trigger offerings_touch_t before update on public.offerings
  for each row execute function public.offerings_touch();


-- ── 누가 보고, 누가 적나 ────────────────────────────────────────────
--  보기: 총·부총관리자는 어디든 · 관리자·행정담당자는 자기 공동체
create or replace function public.offering_can_read(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and ( me.community_role in ('super_admin','vice_admin')
          or ( me.community_id = cid
               and me.community_role in ('community_admin','admin_officer') ) )
  );
$$;
grant execute on function public.offering_can_read(uuid) to authenticated;

--  적기: 총관리자는 어디든 · 나머지는 **자기 공동체 안에서만**
--  (부총관리자는 남의 공동체를 눈으로만 봅니다 — 여기서도 똑같습니다)
create or replace function public.offering_can_write(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and ( me.community_role = 'super_admin'
          or ( me.community_id = cid
               and me.community_role in ('vice_admin','community_admin','admin_officer') ) )
  );
$$;
grant execute on function public.offering_can_write(uuid) to authenticated;

alter table public.offerings enable row level security;

drop policy if exists offerings_select on public.offerings;
create policy offerings_select on public.offerings
  for select to authenticated
  using ( public.offering_can_read(community_id) );

drop policy if exists offerings_insert on public.offerings;
create policy offerings_insert on public.offerings
  for insert to authenticated
  with check ( public.offering_can_write(community_id) );

drop policy if exists offerings_update on public.offerings;
create policy offerings_update on public.offerings
  for update to authenticated
  using      ( public.offering_can_write(community_id) )
  with check ( public.offering_can_write(community_id) );

drop policy if exists offerings_delete on public.offerings;
create policy offerings_delete on public.offerings
  for delete to authenticated
  using ( public.offering_can_write(community_id) );

grant select, insert, update, delete on public.offerings to authenticated;
