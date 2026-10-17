-- =====================================================================
--  📞 통화 — 1단계 (누가 누구에게 걸 수 있나 · 통화 기록)
--
--  실제 소리와 영상은 기기끼리 바로 주고받습니다(WebRTC). 이 표는
--  '지금 벨이 울리고 있다' 를 알리고, 지난 통화를 남겨 두는 자리입니다.
--  소리는 녹음하지 않습니다. 서버를 지나가지도 않습니다.
--
--  ⚠️ 누가 걸었고 누가 받았는지는 교직원이 볼 수 있게 했습니다.
--     채팅이 이미 그렇고(총관리자는 모든 방을 봅니다), 미성년자가 쓰는
--     앱에서 통화만 아무 기록이 없으면 나중에 곤란해집니다.
--     내용은 안 남고, 건 사람·받은 사람·시각·길이만 남습니다.
--
--  ⚠️ 학생끼리는 못 겁니다 — 1:1 채팅 규칙을 그대로 따릅니다.
--     화면에서도 막지만, 화면만 믿으면 아무나 아무에게 걸 수 있습니다.
--
--  ※ db/전체잠그기_RLS.sql 과 db/신고차단_DB설치.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 누구에게 걸 수 있나 ─────────────────────────────────────────
--  1:1 채팅과 같은 규칙. 한 군데서 정해 두고 양쪽이 같이 쓴다.
create or replace function public.can_call(p_other uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1
      from public.members me
      join public.members o on o.id = p_other
     where me.id = auth.uid()
       and me.id <> o.id
       and coalesce(o.status, 'active') <> 'removed'
       and coalesce(me.status, 'active') <> 'removed'
       -- 같은 공동체 (총·부총관리자는 전부)
       and ( me.community_id = o.community_id
             or me.community_role in ('super_admin','vice_admin') )
       -- 학생끼리는 못 건다.
       --  ⚠️ coalesce 를 빼면 안 된다. role 칸이 비어 있는 사람이 많은데,
       --     SQL 에서 NULL = '학생' 은 거짓이 아니라 '모름' 이다. 그 '모름'
       --     이 조건 전체를 물들여서, 아무도 전화를 못 거는 상태가 된다.
       and not ( (coalesce(me.community_role,'') = 'student' or coalesce(me.role,'') = '학생')
                 and (coalesce(o.community_role,'') = 'student' or coalesce(o.role,'') = '학생') )
       and coalesce(o.community_role,'') <> 'store_bot'
  );
$$;
grant execute on function public.can_call(uuid) to authenticated;

-- ── 통화 ────────────────────────────────────────────────────────
create table if not exists public.calls (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null,
  channel_id   uuid,                       -- 어느 방에서 걸었나 (없을 수 있다)
  caller_id    uuid not null,
  callee_id    uuid not null,
  kind         text not null default 'audio' check (kind in ('audio','video')),
  status       text not null default 'ringing'
               check (status in ('ringing','accepted','declined','missed','ended','canceled','failed')),
  answered_at  timestamptz,                -- 받은 때
  ended_at     timestamptz,
  end_reason   text,
  created_at   timestamptz not null default now()
);

create index if not exists calls_callee_idx on public.calls (callee_id, created_at desc);
create index if not exists calls_caller_idx on public.calls (caller_id, created_at desc);
-- 벨이 울리는 중인 통화를 빨리 찾으려고
create index if not exists calls_ringing_idx on public.calls (callee_id) where status = 'ringing';

comment on table public.calls is
  '통화 기록. 소리·영상은 기기끼리 바로 주고받으며 여기에 남지 않는다. 건 사람·받은 사람·시각·길이만.';

alter table public.calls enable row level security;

-- 내 통화는 내가, 공동체 통화 기록은 교직원이 본다
drop policy if exists calls_select on public.calls;
create policy calls_select on public.calls
  for select to authenticated
  using ( caller_id = auth.uid() or callee_id = auth.uid() or public.staff_of(community_id) );

-- 내 이름으로만, 걸 수 있는 사람에게만
drop policy if exists calls_insert on public.calls;
create policy calls_insert on public.calls
  for insert to authenticated
  with check ( caller_id = auth.uid()
               and public.can_call(callee_id)
               and community_id = public.my_community_id() );

-- 받기·거절·끊기는 당사자 둘만
drop policy if exists calls_update on public.calls;
create policy calls_update on public.calls
  for update to authenticated
  using ( caller_id = auth.uid() or callee_id = auth.uid() )
  with check ( caller_id = auth.uid() or callee_id = auth.uid() );

-- 통화 기록은 지우지 않는다. 지울 수 있으면 기록이 아니다.
grant select, insert, update on public.calls to authenticated;

-- 벨이 울리려면 이 표의 변화가 실시간으로 와야 한다
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.calls;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select policyname as "정책", cmd as "대상"
  from pg_policies where schemaname='public' and tablename='calls' order by 2, 1;
