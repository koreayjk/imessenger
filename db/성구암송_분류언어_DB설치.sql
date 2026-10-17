-- =====================================================================
--  📜 성구암송 — 분류(A~E · 주제)와 언어(한글 · 영어)
--
--  네비게이토 주제별 성구암송(TMS)은 다섯 묶음 × 주제 여섯 × 두 구절
--  = 60구절입니다. 묶음과 주제를 담을 칸이 필요합니다.
--
--  그리고 한글과 영어를 '따로' 체크합니다. 한글로 외운 것과 영어로
--  외운 것은 다른 일이니까요. 같은 구절이라도 줄을 따로 둡니다.
--
--  ※ db/성구암송_DB설치.sql 을 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.memory_items') is null then
    raise exception '먼저 db/성구암송_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

alter table public.memory_items
  add column if not exists lang   text not null default 'ko',
  add column if not exists series text,          -- 'A. 새로운 삶'
  add column if not exists topic  text;          -- '중심되신 그리스도'

alter table public.memory_items drop constraint if exists memory_items_lang_ok;
alter table public.memory_items add constraint memory_items_lang_ok
  check (lang in ('ko','en'));

-- 같은 번호라도 언어가 다르면 다른 줄이다
drop index if exists public.memory_items_uq;
create unique index if not exists memory_items_uq2
  on public.memory_items (kind, lang, no, coalesce(community_id, '00000000-0000-0000-0000-000000000000'::uuid));

create index if not exists memory_items_kind_lang_idx
  on public.memory_items (kind, lang, sort, no);

comment on column public.memory_items.lang is
  'ko = 한글 · en = 영어. 같은 구절이라도 줄을 따로 두어 각각 체크한다.';
comment on column public.memory_items.series is '큰 묶음 (예: A. 새로운 삶)';
comment on column public.memory_items.topic  is '주제 (예: 중심되신 그리스도)';

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select kind as "갈래", lang as "말", count(*) as "항목 수"
  from public.memory_items group by 1,2 order by 1,2;
