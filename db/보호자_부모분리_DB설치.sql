-- =====================================================================
--  👨‍👩‍👧 보호자 — 아버지·어머니로 나누기
--
--  생활기록부 인적사항의 '보호자'가 한 칸이라 부모를 둘 다 적을 수
--  없었습니다. 아버지·어머니 칸을 따로 만듭니다.
--
--  이미 '보호자'에 적어 둔 것은 그대로 둡니다. 그 칸은
--  '그 밖의 보호자'(조부모·위탁 등)로 이름만 바뀝니다.
--  기록부 인쇄에는 적어 둔 줄만 나옵니다 — 빈 줄은 안 찍힙니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.members
  add column if not exists father_name  text,
  add column if not exists father_phone text,
  add column if not exists mother_name  text,
  add column if not exists mother_phone text;

comment on column public.members.father_name  is '아버지 성명';
comment on column public.members.father_phone is '아버지 연락처';
comment on column public.members.mother_name  is '어머니 성명';
comment on column public.members.mother_phone is '어머니 연락처';

notify pgrst, 'reload schema';

-- ── 확인 ──
select column_name as "칸"
  from information_schema.columns
 where table_schema = 'public' and table_name = 'members'
   and column_name in ('guardian_name','guardian_phone','father_name','father_phone','mother_name','mother_phone')
 order by 1;

-- =====================================================================
--  내 정보 화면과 생활기록부 인적사항 양쪽에서 적을 수 있습니다.
--  한쪽에 적으면 다른 쪽에도 같이 들어갑니다.
-- =====================================================================
