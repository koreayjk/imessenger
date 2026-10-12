-- =====================================================================
--  🚩 신고 · 🚫 차단 · 🙈 채팅 조정
--
--  구글 플레이의 '사용자 제작 콘텐츠(UGC)' 정책은 채팅이 있는 앱에
--  세 가지를 요구합니다.
--    ① 불쾌한 콘텐츠·사용자를 신고하는 수단
--    ② 다른 사용자를 차단하는 수단
--    ③ 신고가 들어오면 조치하는 운영 체계
--  TCS 는 관리자 승인을 받아야 들어오는 닫힌 공동체라 실제 위험은
--  낮지만, 심사자는 그 사정을 모르고 설문만 봅니다. 셋 다 '아니요'
--  이면 정책 위반으로 반려됩니다. 그래서 실제로 만듭니다.
--
--  이 파일이 하는 일
--    1. message_reports — 신고함
--    2. user_blocks     — 내가 차단한 사람
--    3. messages 에 hidden_at/hidden_by/hidden_reason — 가려진 메시지
--    4. messages 의 고치기·지우기 권한을 '본인 또는 교직원' 으로 좁힘
--
--  ⚠️ 4번은 지금 열려 있는 구멍을 막는 일이기도 합니다.
--     지금은 같은 공동체 사람이면 누구나 API 로 남의 메시지를 고치거나
--     지울 수 있습니다. 화면에서 ✕ 가 내 메시지에만 보일 뿐입니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 0. 도우미 ────────────────────────────────────────────────────
--  다른 설치 파일에서 이미 만들었을 수 있지만, 이 파일만 돌려도 되도록
--  같이 둡니다. (내용 동일)

create or replace function public.my_channel_ids()
returns setof uuid language sql security definer stable parallel safe
set search_path = public as $$
  select c.id from public.channels c
   where exists (select 1 from public.members me
                  where me.id = auth.uid()
                    and (me.community_id = c.community_id
                         or me.community_role in ('super_admin','vice_admin')));
$$;
grant execute on function public.my_channel_ids() to authenticated;

create or replace function public.staff_of(cid uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and ( me.community_role in ('super_admin','vice_admin')
          or ( me.community_id = cid
               and me.community_role in ('community_admin','admin_officer','teacher','staff') ) )
  );
$$;
grant execute on function public.staff_of(uuid) to authenticated;

-- 이 채팅방을 조정할 수 있는 사람인가 (= 그 방이 속한 공동체의 교직원)
create or replace function public.can_moderate_channel(ch uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.channels c
                  where c.id = ch and public.staff_of(c.community_id));
$$;
grant execute on function public.can_moderate_channel(uuid) to authenticated;

-- 이 메시지를 조정할 수 있는가 (신고함에서 메시지를 가리거나 지울 때)
create or replace function public.can_moderate_message(msg uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.messages m
                  where m.id = msg and public.can_moderate_channel(m.channel_id));
$$;
grant execute on function public.can_moderate_message(uuid) to authenticated;


-- ── 1. 가려진 메시지 ─────────────────────────────────────────────
--  지우지 않고 가립니다. 지우면 신고를 처리한 근거가 같이 사라집니다.
--  가린 메시지는 모두에게 "관리자가 가린 메시지입니다" 로 보이고,
--  원문은 교직원만 펼쳐 볼 수 있습니다.
alter table public.messages add column if not exists hidden_at     timestamptz;
alter table public.messages add column if not exists hidden_by     uuid;
alter table public.messages add column if not exists hidden_reason text;

comment on column public.messages.hidden_at is
  '관리자가 가린 시각. 비어 있으면 정상 메시지.';


-- ── 2. 신고함 ────────────────────────────────────────────────────
create table if not exists public.message_reports (
  id                 uuid primary key default gen_random_uuid(),
  message_id         uuid references public.messages(id) on delete set null,
  channel_id         uuid,
  channel_name       text,
  community_id       uuid not null,
  reporter_id        uuid not null references public.members(id) on delete cascade,
  reporter_name      text,
  reported_member_id uuid,                     -- 신고당한 사람
  reported_name      text,
  reason             text not null,            -- abuse | sexual | violence | harass | spam | privacy | etc
  detail             text,
  -- 신고 당시의 내용을 그대로 떠 둔다. 신고당한 사람이 바로 지워 버리면
  -- 관리자가 무엇을 신고한 건지 알 수 없게 되기 때문이다.
  snapshot_text      text,
  snapshot_at        timestamptz,
  status             text not null default 'open',   -- open | resolved | dismissed
  action_taken       text,                     -- hidden | deleted | warned | removed | none
  handled_by         uuid,
  handled_name       text,
  handled_at         timestamptz,
  handled_note       text,
  created_at         timestamptz not null default now()
);
create index if not exists message_reports_comm_idx on public.message_reports (community_id, status, created_at desc);
create index if not exists message_reports_msg_idx  on public.message_reports (message_id);

comment on table public.message_reports is
  '채팅 메시지 신고. 교직원이 운영관리 → 신고함에서 처리한다.';

alter table public.message_reports enable row level security;

-- 보기 — 내가 넣은 신고, 그리고 그 공동체의 교직원
--  신고당한 사람에게는 보이지 않는다. 보이면 보복이 생긴다.
drop policy if exists message_reports_select on public.message_reports;
create policy message_reports_select on public.message_reports for select to authenticated
using ( reporter_id = auth.uid() or public.staff_of(community_id) );

-- 넣기 — 자기 이름으로만, 자기가 볼 수 있는 방의 메시지에 대해서만
drop policy if exists message_reports_insert on public.message_reports;
create policy message_reports_insert on public.message_reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and coalesce(status,'open') = 'open'
  and channel_id in (select public.my_channel_ids())
);

-- 처리 — 교직원만. 신고한 사람은 고치지 못한다.
drop policy if exists message_reports_update on public.message_reports;
create policy message_reports_update on public.message_reports for update to authenticated
using      ( public.staff_of(community_id) )
with check ( public.staff_of(community_id) );

-- 지우기 — 아직 처리 전인 내 신고(잘못 눌렀을 때), 또는 교직원
drop policy if exists message_reports_delete on public.message_reports;
create policy message_reports_delete on public.message_reports for delete to authenticated
using ( (reporter_id = auth.uid() and status = 'open') or public.staff_of(community_id) );

grant select, insert, update, delete on public.message_reports to authenticated;


-- ── 3. 차단 목록 ─────────────────────────────────────────────────
--  차단은 '내 눈에만' 적용됩니다. 상대는 차단당한 사실을 알 수 없습니다.
--  (알리면 그 자체가 다툼거리가 됩니다)
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.members(id) on delete cascade,
  blocked_id uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
create index if not exists user_blocks_blocker_idx on public.user_blocks (blocker_id);

comment on table public.user_blocks is
  '내가 차단한 사람. 차단한 사람의 메시지는 접혀서 보인다. 상대에게는 알리지 않는다.';

alter table public.user_blocks enable row level security;

-- 내 차단 목록만 보고, 만들고, 지운다. 남이 나를 차단했는지는 알 수 없다.
drop policy if exists user_blocks_select on public.user_blocks;
create policy user_blocks_select on public.user_blocks for select to authenticated
using ( blocker_id = auth.uid() );

drop policy if exists user_blocks_insert on public.user_blocks;
create policy user_blocks_insert on public.user_blocks for insert to authenticated
with check ( blocker_id = auth.uid() and blocked_id <> auth.uid() );

drop policy if exists user_blocks_delete on public.user_blocks;
create policy user_blocks_delete on public.user_blocks for delete to authenticated
using ( blocker_id = auth.uid() );

grant select, insert, delete on public.user_blocks to authenticated;


-- ── 4. 메시지 권한 조이기 ────────────────────────────────────────
--  허용 정책은 OR 로 합쳐집니다. 그래서 더하지 않고, 싹 걷어내고 새로
--  네 줄만 깝니다. 더하면 조용히 더 열립니다.
--
--    보기   — 내 공동체의 채팅방 (지금과 같음)
--    넣기   — 내 이름으로, 내가 볼 수 있는 방에
--    고치기 — 내 메시지, 또는 그 방을 조정할 수 있는 교직원
--    지우기 — 내 메시지, 또는 그 방을 조정할 수 있는 교직원
--
--  네 번째가 핵심입니다. 지금은 같은 공동체이기만 하면 남의 메시지를
--  지울 수 있습니다.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
            where schemaname='public' and tablename='messages'
  loop
    execute format('drop policy if exists %I on public.messages', p.policyname);
  end loop;
end $$;

alter table public.messages enable row level security;

create policy messages_select on public.messages for select to authenticated
using ( channel_id in (select public.my_channel_ids()) );

create policy messages_insert on public.messages for insert to authenticated
with check ( sender_id = auth.uid() and channel_id in (select public.my_channel_ids()) );

-- 'hidden_at is null' 이 붙은 이유:
--  이게 없으면 교사가 가린 메시지를 글쓴이가 API 로 바로 되돌릴 수 있다.
--  (실제로 시험에서 1행이 바뀌었다) 글쓴이는 스스로 가리지도 못한다 —
--  with check 에서 걸린다. 지우고 싶으면 지우면 된다.
--  가려진 뒤에는 글쓴이가 손댈 수 없다. 조정이 그제서야 조정이 된다.
create policy messages_update on public.messages for update to authenticated
using      ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) )
with check ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) );

create policy messages_delete on public.messages for delete to authenticated
using ( public.can_moderate_channel(channel_id)
        or (sender_id = auth.uid() and hidden_at is null) );

grant select, insert, update, delete on public.messages to authenticated;

create index if not exists messages_channel_idx on public.messages (channel_id);

notify pgrst, 'reload schema';


-- ── 확인 ─────────────────────────────────────────────────────────
select tablename as "표", policyname as "정책", cmd as "대상"
  from pg_policies
 where schemaname='public'
   and tablename in ('messages','message_reports','user_blocks')
 order by 1, 3, 2;

-- =====================================================================
--  화면에 생기는 것
--    · 메시지 위 단추에 🚩 (남의 메시지일 때) — 신고
--    · 교직원에게는 🙈 — 메시지 가리기 / 되돌리기
--    · 내 프로필 맨 아래 🚫 차단 목록 — 차단 · 차단 해제
--    · 운영관리 → 🚩 신고함 — 신고 목록과 처리
--
--  플레이 콘솔 설문은 이제 셋 다 '예' 입니다.
--    사용자/콘텐츠 차단 기능  → 예
--    사용자/콘텐츠 신고 기능  → 예
--    채팅 조정                → 예
-- =====================================================================
