-- =====================================================================
--  재정 · 입출금 분류(category) 대소문자 중복 통일
--  예) "students' Living Cost Donation" → "Students' Living Cost Donation"
--      "repayment" → "Repayment"
--  대소문자만 다른 값을 표준 표기(앱의 공식 카테고리)로 합칩니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

update public.finance_transactions t
set category = c.canon
from (values
  ('Students'' Living Cost Donation'),
  ('Special Donations'),
  ('Moving Donations'),
  ('Church Donations'),
  ('Scholarships'),
  ('Repayment'),
  ('Grocery'),
  ('Fuel (Oil)'),
  ('Eating Out'),
  ('Housing fee'),
  ('Utilities'),
  ('Monthly payment'),
  ('Office&School Supply'),
  ('Auto Payment'),
  ('Auto Insurance'),
  ('Car Maintenance'),
  ('EZ Pass'),
  ('Travel'),
  ('Air Fair'),
  ('Activity'),
  ('Basic necessities'),
  ('Build up Project'),
  ('Books/Christian Education'),
  ('MultiMedia Supply'),
  ('Staff Wage'),
  ('MJ Wage'),
  ('Kitchen Supply'),
  ('Local Mission'),
  ('CPA'),
  ('Credit Card'),
  ('Misc. Exp.')
) as c(canon)
where lower(trim(t.category)) = lower(c.canon)
  and t.category is distinct from c.canon;

-- 앞뒤 공백만 있는 값도 정리
update public.finance_transactions
set category = trim(category)
where category <> trim(category);
