-- =====================================================================
--  재정 캐쉬북 : 분류 학습 (내가 고친 분류를 기억해 다음 업로드에 반영)
--  거래 설명을 정규화한 key 별로 카테고리를 저장해 두고,
--  다음에 같은/비슷한 거래가 올라오면 그 분류를 자동 적용합니다.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

create table if not exists public.finance_category_rules (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  match_key     text not null,         -- 거래 설명에서 뽑은 가맹점/상대 키 (앱의 finLearnKey)
  category      text not null,
  sample_desc   text,                  -- 참고용: 규칙이 만들어진 원본 설명
  hits          int  not null default 1,
  updated_by    uuid,
  updated_at    timestamptz not null default now()
);
create unique index if not exists uq_fin_cat_rule
  on public.finance_category_rules (community_id, match_key);

alter table public.finance_category_rules enable row level security;

drop policy if exists fin_rule_select on public.finance_category_rules;
create policy fin_rule_select on public.finance_category_rules
  for select to authenticated using (public.is_finance_staff());

drop policy if exists fin_rule_insert on public.finance_category_rules;
create policy fin_rule_insert on public.finance_category_rules
  for insert to authenticated with check (public.is_finance_staff());

drop policy if exists fin_rule_update on public.finance_category_rules;
create policy fin_rule_update on public.finance_category_rules
  for update to authenticated using (public.is_finance_staff()) with check (public.is_finance_staff());

drop policy if exists fin_rule_delete on public.finance_category_rules;
create policy fin_rule_delete on public.finance_category_rules
  for delete to authenticated using (public.is_finance_staff());

NOTIFY pgrst, 'reload schema';
