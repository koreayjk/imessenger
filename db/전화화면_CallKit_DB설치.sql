-- =====================================================================
--  📞 아이폰 전화 화면 (CallKit) — 표 한 줄 더 받기
--
--  지금까지 애플이 주는 표는 하나였습니다(알림용). 전화 화면을 띄우려면
--  **VoIP 푸시**라는 다른 길을 써야 하고, 애플은 그 길의 표를 **따로**
--  줍니다. 한 줄에 같이 둘 수 없어서 kind = 'ios_voip' 로 한 줄 더 받습니다.
--
--  ⚠️ 지금 걸려 있는 제약은 kind 를 'web' 과 'ios' 로만 막아 둡니다.
--     이걸 안 넓히면 표가 **조용히 저장되지 않고**, 전화 화면이 영영
--     안 뜹니다 (오류는 콘솔에만 남습니다).
--
--  열쇠는 지금 쓰는 APNs .p8 을 그대로 씁니다. 애플에 따로 받을 것이
--  없습니다. 서버가 보낼 때 주소 뒤에 .voip 를 붙입니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.push_subscriptions drop constraint if exists push_subs_kind_ok;
alter table public.push_subscriptions add constraint push_subs_kind_ok check (
  (kind = 'web' and p256dh is not null and auth is not null)
  or kind in ('ios', 'ios_voip')
);

comment on column public.push_subscriptions.kind is
  'web = 브라우저 웹푸시 (endpoint 는 주소) | ios = 애플 APNs 알림 (기기 표) '
  '| ios_voip = 애플 VoIP 푸시 (전화 화면용 기기 표)';

notify pgrst, 'reload schema';


-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "길", count(*) as "기기 수"
  from public.push_subscriptions group by kind order by 1;

--  제약이 넓어졌나 (ios_voip 가 들어 있어야 합니다)
select pg_get_constraintdef(oid) as "kind 제약"
  from pg_constraint where conname = 'push_subs_kind_ok';
