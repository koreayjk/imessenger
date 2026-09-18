-- ═══════════════════════════════════════════════════════════════
--  전자결재 — 개인 서명(싸인)
--
--  프로필에 서명을 한 번 그려 두면, 결재를 승인할 때 그 서명이
--  결재란에 자동으로 찍힙니다.
--
--  Supabase → SQL Editor 에 붙여넣고 [Run]. 여러 번 실행해도 안전합니다.
--
--  ※ 서명 그림은 다른 첨부와 같은 messenger 버킷에 올라갑니다.
--    이 버킷은 공개(public) 라 주소를 아는 사람은 볼 수 있습니다.
--    (주소에 멤버 id 와 시각이 들어가 있어 추측하기는 어렵습니다)
--    더 엄격하게 막고 싶으시면 말씀해 주세요 — 비공개 버킷 + 서명된 주소로
--    바꿀 수 있습니다.
-- ═══════════════════════════════════════════════════════════════

alter table public.members add column if not exists signature_url text;

comment on column public.members.signature_url is
  '개인 서명 이미지 주소. 전자결재 승인 시 결재란에 찍힌다';

NOTIFY pgrst, 'reload schema';

-- ── 확인 ──
-- 아래가 1줄 나오면 설치 완료입니다.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'members' and column_name = 'signature_url';
