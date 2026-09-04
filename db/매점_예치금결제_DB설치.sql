-- =====================================================================
--  매점 결제수단에 '예치금 차감' 추가
--  store_sales 에 예치금 지출 연결 컬럼을 추가합니다. (판매 취소 시 함께 삭제)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

alter table public.store_sales
  add column if not exists deposit_entry_id uuid;

comment on column public.store_sales.pay_method is
  '결제수단: allowance(용돈차감) | cash(현금) | deposit(예치금차감)';

NOTIFY pgrst, 'reload schema';
