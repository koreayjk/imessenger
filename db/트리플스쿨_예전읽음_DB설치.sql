-- =====================================================================
--  📖 트리플스쿨 — '예전에 읽었어요' 바로 체크
--
--  요청: "이전에 읽었던 트리플 스쿨을 기록하려 하는데 독후감을 작성해야
--   해서 어려움이 있네요! 혹시 바로 체크가 가능하게끔 하는 기능을
--   추가해 주실 수 있으실까요?"
--
--  지금은 독후감 60단어를 채워야만 '읽음' 이 됩니다. 입학 전에 읽은
--  책까지 전부 다시 독후감을 쓰게 하는 건 무리입니다.
--
--  ⚠️ 다만 '독후감을 쓴 읽음' 과 '예전에 읽은 체크' 는 구별해야 합니다.
--     같아 보이면 선생님이 진도를 잘못 읽습니다. prior_read 로 가립니다.
--     생활기록부(PDF)에도 들어가지 않습니다 — 담을 글이 없습니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regclass('public.reading_logs') is null then
    raise exception '먼저 트리플스쿨(필독서) DB 설치를 해주세요.';
  end if;
end $$;

-- 예전에 읽은 체크인가
alter table public.reading_logs
  add column if not exists prior_read boolean not null default false;

-- 언제 읽었는지 기억 안 날 수 있습니다. 비워둘 수 있게 합니다.
-- (칸 이름이 다른 곳에서도 멈추지 않게 있을 때만 건드립니다)
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='reading_logs'
                and column_name='read_date' and is_nullable='NO') then
    execute 'alter table public.reading_logs alter column read_date drop not null';
  end if;
end $$;

comment on column public.reading_logs.prior_read is
  'true = 독후감 없이 ''예전에 읽었다'' 고만 체크한 것. 생활기록부에는 넣지 않는다.';

create index if not exists reading_logs_prior_idx
  on public.reading_logs (student_id, prior_read);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select
  count(*)                                   as "전체 읽음",
  count(*) filter (where prior_read)          as "예전에 읽음 체크",
  count(*) filter (where not prior_read)      as "독후감 쓴 것"
from public.reading_logs;
