-- =====================================================================
--  🔔 2단계 — 앱을 닫아도 오는 알림 (웹푸시)
--
--  1단계는 앱이 켜져 있을 때만 알렸습니다. 휴대폰에서 앱을 닫아 두면
--  소용이 없습니다. 브라우저가 앱 대신 알림을 받아 주게 하려면,
--  그 브라우저의 '받을 주소' 를 서버가 알고 있어야 합니다.
--
--  기기마다 주소가 따로입니다. 한 사람이 노트북·휴대폰 둘 다 쓰면
--  줄이 두 개 생깁니다. 그래서 member_id 가 아니라 endpoint 가 열쇠입니다.
--
--  ⚠️ 이 표의 p256dh·auth 는 그 기기로 보낼 알림을 암호화하는 열쇠입니다.
--     남이 가져가면 그 기기에 알림을 보낼 수 있습니다. 본인 줄만
--     읽고 쓸 수 있게 막아 둡니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  member_id  uuid not null references public.members(id) on delete cascade,
  endpoint   text not null unique,       -- 이 기기로 보내는 주소
  p256dh     text not null,              -- 암호화 열쇠
  auth       text not null,
  ua         text,                       -- 어느 기기인지 (목록에 보여주려고)
  created_at timestamptz not null default now(),
  last_ok_at timestamptz,                -- 마지막으로 잘 보내진 때
  fail_count int not null default 0,     -- 연달아 실패하면 치운다
  -- 이 기기의 알림 설정. 보내는 쪽이 서버라서, 서버도 알아야 한다.
  -- 1단계는 설정이 브라우저 안에만 있어서 서버가 볼 수 없었다.
  enabled      boolean not null default true,
  only_mention boolean not null default false,
  preview      boolean not null default true,
  mutes        text    not null default ''   -- 알림 끈 방. channel_id 를 쉼표로
);
create index if not exists push_subs_member_idx on public.push_subscriptions (member_id);

-- 먼저 깔았던 분들을 위해 (재실행해도 안전)
alter table public.push_subscriptions add column if not exists enabled      boolean not null default true;
alter table public.push_subscriptions add column if not exists only_mention boolean not null default false;
alter table public.push_subscriptions add column if not exists preview      boolean not null default true;
alter table public.push_subscriptions add column if not exists mutes        text    not null default '';

comment on table public.push_subscriptions is
  '웹푸시 받을 주소. 기기마다 한 줄. 끄거나 브라우저를 지우면 사라진다.';

alter table public.push_subscriptions enable row level security;

-- 내 것만 보고, 만들고, 고치고, 지운다.
drop policy if exists push_subs_select on public.push_subscriptions;
create policy push_subs_select on public.push_subscriptions
  for select to authenticated using ( member_id = auth.uid() );

drop policy if exists push_subs_insert on public.push_subscriptions;
create policy push_subs_insert on public.push_subscriptions
  for insert to authenticated with check ( member_id = auth.uid() );

drop policy if exists push_subs_update on public.push_subscriptions;
create policy push_subs_update on public.push_subscriptions
  for update to authenticated
  using ( member_id = auth.uid() ) with check ( member_id = auth.uid() );

drop policy if exists push_subs_delete on public.push_subscriptions;
create policy push_subs_delete on public.push_subscriptions
  for delete to authenticated using ( member_id = auth.uid() );

grant select, insert, update, delete on public.push_subscriptions to authenticated;

-- 보내는 쪽(Edge Function)은 service_role 로 들어오므로 RLS 를 지나갑니다.
-- 거기서 '이 사람이 그 방에 있는가' 를 다시 확인합니다.

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select policyname as "정책", cmd as "대상"
  from pg_policies where schemaname='public' and tablename='push_subscriptions'
 order by 2, 1;

-- =====================================================================
--  다음: Edge Function `push-notify` 를 배포하고, 비밀값 두 개를 넣으세요.
--    supabase secrets set VAPID_PUBLIC=...  VAPID_PRIVATE=...  VAPID_SUBJECT=mailto:...
--  (키와 명령은 안내문에 그대로 적어 두었습니다)
-- =====================================================================
