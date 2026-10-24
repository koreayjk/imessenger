-- =====================================================================
--  📋 일일기록 · 📬 주간 학부모 피드백
--
--  왜 두 개인가 —
--    일일기록은 '선생님이 매일 2~3분 적는 내부 기록' 입니다. 학부모는
--    못 봅니다. 솔직하게 적어야 재료가 되기 때문입니다.
--    주간 피드백은 '그 재료에서 골라 학부모께 드리는 글' 입니다.
--    매일 긴 보고를 보내면 정작 중요한 연락이 묻힙니다.
--
--  ⚠️ 일일기록은 교직원만 봅니다 — 상담·관찰기록과 같습니다.
--  ⚠️ 주간 피드백은 '보냄' 으로 바꾼 것만 학부모가 봅니다.
--     초안을 쓰다 만 글이 학부모께 보이면 안 됩니다.
--  ⚠️ 학생 본인은 주간 피드백도, 그 아래 댓글도 못 봅니다.
--     선생님이 '아직 스스로 시작하지 못합니다' 를 쓸 수 있어야 하고,
--     학부모도 걱정을 편히 적을 수 있어야 합니다.
--
--  ※ db/전체잠그기_RLS.sql 과 db/학부모_1_칸막이_DB설치.sql 을 먼저 하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 기대는 함수들 ───────────────────────────────────────────────
--  학부모_1_칸막이 에도 똑같이 있습니다. 그걸 안 깔았으면 여기서
--  멈추므로, 같은 내용으로 한 번 더 둡니다.
create or replace function public.my_children() returns setof uuid
language sql stable security definer parallel safe set search_path = public as $$
  select sp.student_id from public.student_parents sp where sp.parent_id = auth.uid();
$$;
grant execute on function public.my_children() to authenticated;

-- ═══════════════════════════════════════════════════════════════
--  📋 일일기록 — 선생님이 매일 적는 내부 기록
-- ═══════════════════════════════════════════════════════════════
--  다섯 영역으로 나눈 까닭: 미국 학교에 다녀온 아이를 방과 후에 맡는
--  구조라, '오늘 뭘 가르쳤나' 가 아니라 '학교가 시킨 걸 파악했나 ·
--  혼자 해냈나 · 스스로 시작했나' 가 기록할 거리이기 때문입니다.
create table if not exists public.daily_logs (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  date          date not null default current_date,

  -- ① School       학교에서 받은 과제·시험·제출기한
  -- ② Academic     과제 수행 — 혼자 한 것과 도움받은 것
  -- ③ Self-manage  스스로 시작했나 · 시간 관리
  -- ④ Life         생활·책임감·도움 요청하는 태도
  -- ⑤ Growth       오늘 자란 것 / 다음에 확인할 것
  school_note   text,
  academic_note text,
  self_note     text,
  life_note     text,
  growth_note   text,

  -- 매일 고르는 것 (글을 안 써도 추세가 쌓이게)
  homework      text check (homework     in ('done','partial','none','na')),
  independence  text check (independence in ('self','some_help','much_help','na')),
  --  ⚠️ 이 칸이 이 기록의 핵심입니다. 유학생은 수학을 틀려도 까닭이
  --     '개념' 일 수도, '영어로 된 문제를 못 읽은 것' 일 수도 있습니다.
  --     이걸 안 가르면 엉뚱한 걸 가르치게 됩니다.
  cause         text check (cause in ('concept','english','careless','time','focus','none')),

  -- 생기부로 보냈나
  to_record      boolean not null default false,
  observation_id uuid,          -- 보낸 관찰기록 줄 (두 번 보내지 않으려고)

  author_name   text,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists daily_logs_student_idx
  on public.daily_logs (community_id, student_id, date desc, created_at desc);
create index if not exists daily_logs_date_idx
  on public.daily_logs (community_id, date desc);

comment on table public.daily_logs is
  '선생님이 매일 적는 내부 학습기록. 교직원만 본다 — 학생도 학부모도 못 본다. 주간 피드백의 재료.';

alter table public.daily_logs enable row level security;

-- 먼저 닫고 쓸 것만 연다 (수파베이스는 새 표에 권한을 전부 기본으로 준다)
revoke all on public.daily_logs from public, anon, authenticated;
grant select, insert, update, delete on public.daily_logs to authenticated;

drop policy if exists daily_logs_rw on public.daily_logs;
create policy daily_logs_rw on public.daily_logs
  for all to authenticated
  using      ( public.staff_of(community_id) )
  with check ( public.staff_of(community_id) );

-- ═══════════════════════════════════════════════════════════════
--  📬 주간 피드백 — 학부모께 드리는 글
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.weekly_feedbacks (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  student_id    uuid not null references public.members(id) on delete cascade,
  week_start    date not null,            -- 그 주 월요일

  summary       text,    -- 이번 주 한눈에
  grew          text,    -- 구체적으로 자란 것 (점수가 아니라 '무엇이 달라졌나')
  working_on    text,    -- 아직 도와야 할 것
  plan          text,    -- 우리가 다음 주에 할 것
  home          text,    -- 가정에서 도와주실 것

  status        text not null default 'draft' check (status in ('draft','sent')),
  sent_at       timestamptz,
  author_name   text,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 한 주에 한 장. 두 장이 가면 학부모가 어느 게 맞는지 모른다.
create unique index if not exists weekly_feedbacks_one_per_week
  on public.weekly_feedbacks (community_id, student_id, week_start);
create index if not exists weekly_feedbacks_student_idx
  on public.weekly_feedbacks (student_id, week_start desc);

comment on table public.weekly_feedbacks is
  '주간 학부모 피드백. status=sent 로 바꾼 것만 학부모가 본다. 학생 본인은 못 본다.';

alter table public.weekly_feedbacks enable row level security;
revoke all on public.weekly_feedbacks from public, anon, authenticated;
grant select, insert, update, delete on public.weekly_feedbacks to authenticated;

--  ⚠️ 학부모는 '보냄' 인 것만. 초안을 쓰다 만 글이 보이면 안 된다.
--  ⚠️ 학생 본인은 빠져 있다 — 일부러 그렇게 두었다.
drop policy if exists weekly_feedbacks_select on public.weekly_feedbacks;
create policy weekly_feedbacks_select on public.weekly_feedbacks
  for select to authenticated
  using ( public.staff_of(community_id)
          or ( status = 'sent' and student_id in (select public.my_children()) ) );

drop policy if exists weekly_feedbacks_write on public.weekly_feedbacks;
create policy weekly_feedbacks_write on public.weekly_feedbacks
  for all to authenticated
  using      ( public.staff_of(community_id) )
  with check ( public.staff_of(community_id) );

-- ═══════════════════════════════════════════════════════════════
--  💬 주간 피드백 댓글 — 학부모가 달고, 우리가 답한다
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.weekly_feedback_comments (
  id           uuid primary key default gen_random_uuid(),
  feedback_id  uuid not null references public.weekly_feedbacks(id) on delete cascade,
  parent_id    uuid references public.weekly_feedback_comments(id) on delete cascade,  -- 대댓글
  author_id    uuid not null,
  author_name  text,
  author_role  text,          -- 'parent' | 'staff' (화면 표시용)
  body         text not null,
  created_at   timestamptz not null default now()
);

create index if not exists wfc_feedback_idx
  on public.weekly_feedback_comments (feedback_id, created_at);

comment on table public.weekly_feedback_comments is
  '주간 피드백 아래 오가는 말. 학부모와 교직원만 본다.';

alter table public.weekly_feedback_comments enable row level security;
revoke all on public.weekly_feedback_comments from public, anon, authenticated;
grant select, insert, update, delete on public.weekly_feedback_comments to authenticated;

--  볼 수 있는 피드백의 댓글만 본다 — 위 규칙을 그대로 따라간다.
--  한 군데서 정해 두면 둘이 어긋날 일이 없다.
create or replace function public.can_see_feedback(p_id uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (
    select 1 from public.weekly_feedbacks f
     where f.id = p_id
       and ( public.staff_of(f.community_id)
             or ( f.status = 'sent' and f.student_id in (select public.my_children()) ) )
  );
$$;
revoke all on function public.can_see_feedback(uuid) from public, anon;
grant execute on function public.can_see_feedback(uuid) to authenticated;

drop policy if exists wfc_select on public.weekly_feedback_comments;
create policy wfc_select on public.weekly_feedback_comments
  for select to authenticated
  using ( public.can_see_feedback(feedback_id) );

-- 내 이름으로만 쓴다. 남의 이름을 달 수 없다.
drop policy if exists wfc_insert on public.weekly_feedback_comments;
create policy wfc_insert on public.weekly_feedback_comments
  for insert to authenticated
  with check ( author_id = auth.uid() and public.can_see_feedback(feedback_id) );

-- 지우는 것은 내 글만. 교직원은 그 공동체 글을 지울 수 있다.
drop policy if exists wfc_delete on public.weekly_feedback_comments;
create policy wfc_delete on public.weekly_feedback_comments
  for delete to authenticated
  using ( author_id = auth.uid()
          or exists (select 1 from public.weekly_feedbacks f
                      where f.id = feedback_id and public.staff_of(f.community_id)) );

-- 고치는 것은 내 글만 (남의 말을 바꿔 놓을 수 없다)
drop policy if exists wfc_update on public.weekly_feedback_comments;
create policy wfc_update on public.weekly_feedback_comments
  for update to authenticated
  using      ( author_id = auth.uid() )
  with check ( author_id = auth.uid() );

-- 댓글이 달리면 바로 보이게
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.weekly_feedback_comments;
    exception when duplicate_object then null; end;
  end if;
end $$;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select tablename as "표", policyname as "정책", cmd as "대상"
  from pg_policies
 where schemaname='public'
   and tablename in ('daily_logs','weekly_feedbacks','weekly_feedback_comments')
 order by 1, 3, 2;

select t as "표",
       coalesce((select string_agg(privilege_type, ',' order by privilege_type)
                   from information_schema.role_table_grants g
                  where g.table_schema='public' and g.table_name=t and g.grantee='anon'), '(없음)') as "익명 권한"
  from unnest(array['daily_logs','weekly_feedbacks','weekly_feedback_comments']) t;

-- 관찰기록이 교직원만 보게 되어 있는지 (학부모_1_칸막이 를 돌렸는지) 확인
select policyname as "관찰기록 정책", cmd as "대상",
       case when qual like '%staff_of%' and qual not like '%true%' then '✅ 교직원만'
            else '⚠️ 열려 있음 — db/학부모_1_칸막이_DB설치.sql 을 실행하세요' end as "상태"
  from pg_policies where schemaname='public' and tablename='observation_logs';
