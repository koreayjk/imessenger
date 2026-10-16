-- =====================================================================
--  🍎 3단계 — 아이폰 앱 알림 (애플 APNs)
--
--  아이폰 앱(Capacitor)에서는 웹푸시가 통하지 않습니다. 서비스워커
--  푸시를 WKWebView 가 받지 못하기 때문입니다. 애플 길로 가야 합니다.
--
--  웹푸시는 '주소 + 암호화 열쇠 두 개' 를 받지만, APNs 는 '기기 표'
--  하나만 받습니다. 모양이 달라 표를 따로 둘까 했지만, 그러면 기기별
--  설정(끈 방·나를 부른 것만·미리보기)을 두 군데서 따로 관리하게 됩니다.
--  한 표에 담고 kind 로 가립니다.
--
--  ※ db/알림_푸시_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.push_subscriptions') is null then
    raise exception '먼저 db/알림_푸시_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

-- 어느 길로 보내는가: web = 웹푸시 · ios = 애플 APNs
alter table public.push_subscriptions
  add column if not exists kind text not null default 'web';

-- APNs 는 암호화 열쇠를 쓰지 않는다. 비워 둘 수 있게 한다.
alter table public.push_subscriptions alter column p256dh drop not null;
alter table public.push_subscriptions alter column auth   drop not null;

-- 웹푸시 줄은 열쇠가 반드시 있어야 하고, APNs 줄은 없어야 맞다.
-- 한쪽이 비면 보낼 때 조용히 실패하므로 표 단계에서 막는다.
alter table public.push_subscriptions drop constraint if exists push_subs_kind_ok;
alter table public.push_subscriptions add constraint push_subs_kind_ok check (
  (kind = 'web' and p256dh is not null and auth is not null)
  or kind = 'ios'
);

create index if not exists push_subs_kind_idx on public.push_subscriptions (member_id, kind);

comment on column public.push_subscriptions.kind is
  'web = 브라우저 웹푸시 (endpoint 는 주소) | ios = 애플 APNs (endpoint 는 기기 표)';

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "길", count(*) as "기기 수"
  from public.push_subscriptions group by kind order by 1;

-- =====================================================================
--  다음 (docs/알림_아이폰_설치안내.md 에 자세히 적어 두었습니다)
--   1. 애플 개발자 사이트에서 APNs 인증 키(.p8) 만들기
--   2. supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=...
--                           APNS_BUNDLE_ID=io.github.koreayjk.tcs
--                           APNS_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"
--   3. supabase functions deploy push-notify
--   4. Xcode 에서 Push Notifications 기능 켜고 다시 빌드
-- =====================================================================
