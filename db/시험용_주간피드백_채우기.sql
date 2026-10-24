-- =====================================================================
--  🧪 시험용 — 학부모 화면을 실제로 보기 위한 가짜 자료
--
--  학부모가 로그인했을 때 '내 아이 → 📬 주간 피드백' 이 어떻게 보이는지
--  직접 확인하려고 두 주치를 미리 채워 넣습니다. 댓글도 한 줄 깔아
--  둡니다 — 오가는 모양까지 봐야 하니까요.
--
--  ⚠️ 글머리마다 [시험용] 이 붙습니다. 실제 아이에 대한 선생님의
--     판단으로 오해되면 안 됩니다. 확인이 끝나면 맨 아래 한 줄로
--     깨끗이 지우세요.
--  ⚠️ 이미 있는 주는 건드리지 않습니다 (on conflict do nothing).
--     진짜로 쓰신 피드백을 덮어쓸 일은 없습니다.
--  ⚠️ '이번 주' 는 비워 둡니다. 선생님이 진짜로 쓰실 자리입니다.
--     지난주와 지지난주에만 넣습니다.
--
--  ※ db/일일기록_주간피드백_DB설치.sql 을 먼저 실행하세요.
--  두 번 돌려도 안전합니다.
-- =====================================================================

do $$
declare
  v_student uuid; v_cid uuid; v_parent uuid; v_staff uuid;
  v_sname text; v_pname text; v_tname text;
  v_last date; v_prev date;
  v_f1 uuid; v_f2 uuid; v_c1 uuid;
begin
  -- 학부모가 연결된 학생을 하나 고릅니다. 연결이 없으면 학부모가
  -- 로그인해도 아무것도 못 보므로, 그런 학생을 골라야 뜻이 있습니다.
  select sp.student_id, sp.parent_id into v_student, v_parent
    from public.student_parents sp
    join public.members s on s.id = sp.student_id
   where coalesce(s.status,'active') <> 'removed'
   order by s.name
   limit 1;

  if v_student is null then
    raise notice '⚠️ 학부모와 연결된 학생이 없습니다.';
    raise notice '   관리자 → 멤버 에서 아이와 학부모를 먼저 연결하세요.';
    raise notice '   (연결이 없으면 학부모가 로그인해도 볼 것이 없습니다)';
    return;
  end if;

  select community_id, name into v_cid, v_sname from public.members where id = v_student;
  select name into v_pname from public.members where id = v_parent;

  -- 쓴 사람으로 적을 교직원 한 명 (학부모가 댓글을 달면 이 사람에게 알림이 갑니다)
  select id, name into v_staff, v_tname
    from public.members
   where community_id = v_cid
     and community_role in ('teacher','staff','community_admin','admin_officer','super_admin','vice_admin')
   order by case community_role when 'teacher' then 1 else 2 end, name
   limit 1;
  if v_staff is null then v_staff := v_parent; v_tname := '선생님'; end if;

  -- 지난주 월요일 · 지지난주 월요일
  v_last := date_trunc('week', current_date)::date - 7;
  v_prev := v_last - 7;

  -- ── 지난주 ──────────────────────────────────────────────────
  insert into public.weekly_feedbacks
    (community_id, student_id, week_start, summary, grew, working_on, plan, home,
     status, sent_at, author_name, created_by)
  values (v_cid, v_student, v_last,
    '[시험용] 이번 주에는 학교 과학 프로젝트와 수학 숙제를 함께 봤어요. 월요일 제출이라 금요일까지 자료 정리를 마쳤습니다.',
    '[시험용] 전에는 모르는 지시문을 그냥 넘어갔는데, 이번 주에는 먼저 물어보기 시작했어요. 수학 숙제 15문제 중 12문제를 혼자 풀었습니다.',
    '[시험용] 영어로 된 문제의 요구사항을 두 가지 놓치는 일이 있었어요. 수학을 몰라서가 아니라 지시문을 끝까지 읽지 않아서였습니다.',
    '[시험용] 다음 주에는 문제를 풀기 전에 지시문에 밑줄을 긋고 무엇을 묻는지 말해보게 하겠습니다.',
    '[시험용] 모르는 것을 먼저 물어본 점을 집에서도 칭찬해 주세요. 그게 이번 주 가장 큰 변화예요.',
    'sent', now() - interval '3 days', v_tname, v_staff)
  on conflict (community_id, student_id, week_start) do nothing
  returning id into v_f1;

  -- ── 지지난주 ────────────────────────────────────────────────
  insert into public.weekly_feedbacks
    (community_id, student_id, week_start, summary, grew, plan,
     status, sent_at, author_name, created_by)
  values (v_cid, v_student, v_prev,
    '[시험용] 분수의 덧셈과 뺄셈을 연습했어요. 학교 단원평가가 있어서 그 범위를 같이 봤습니다.',
    '[시험용] 통분을 왜 하는지 자기 말로 설명할 수 있게 되었어요. 전에는 방법만 외우고 있었습니다.',
    '[시험용] 풀이를 마친 뒤 스스로 검산하는 습관을 들이겠습니다.',
    'sent', now() - interval '10 days', v_tname, v_staff)
  on conflict (community_id, student_id, week_start) do nothing
  returning id into v_f2;

  -- ── 댓글 한 줄 + 답글 (오가는 모양까지 보려고) ───────────────
  if v_f1 is not null then
    insert into public.weekly_feedback_comments
      (feedback_id, author_id, author_name, author_role, body, created_at)
    values (v_f1, v_parent, coalesce(v_pname,'학부모'), 'parent',
      '[시험용] 집에서도 요즘 먼저 물어보더라고요. 칭찬해 주었습니다. 감사합니다!',
      now() - interval '2 days')
    returning id into v_c1;

    insert into public.weekly_feedback_comments
      (feedback_id, parent_id, author_id, author_name, author_role, body, created_at)
    values (v_f1, v_c1, v_staff, coalesce(v_tname,'선생님'), 'staff',
      '[시험용] 감사합니다. 다음 주에는 지시문 읽기를 같이 연습해 보겠습니다.',
      now() - interval '2 days' + interval '3 hours');
  end if;

  -- ── 일일기록도 며칠치 (선생님 화면 확인용 · 학부모는 못 봅니다) ──
  insert into public.daily_logs
    (community_id, student_id, date, school_note, academic_note, self_note, life_note, growth_note,
     homework, independence, cause, author_name, created_by)
  select v_cid, v_student, d.dt, s.school, s.academic, s.selfm, s.life, s.growth,
         s.hw, s.ind, s.cause, v_tname, v_staff
    from (values
      (v_last + 1, '[시험용] 과학 프로젝트 안내문 받음 (월요일 제출)',
                   '[시험용] 수학 숙제 15문제 중 12문제를 혼자 풀었음',
                   '[시험용] 휴대전화로 시작이 늦었으나 계획표를 쓴 뒤 스스로 마무리함',
                   '[시험용] 모르는 지시문을 먼저 물어봄',
                   '[시험용] 전에는 그냥 넘어갔는데 오늘은 먼저 질문함',
                   'partial', 'some_help', 'english'),
      (v_last + 2, '[시험용] 영어 읽기 과제 받음',
                   '[시험용] 지시문의 요구사항 두 가지를 놓쳐 설명 후 수정함',
                   '[시험용] 시작 시간을 스스로 지킴', null,
                   '[시험용] 고친 뒤 같은 실수를 반복하지 않음',
                   'done', 'self', 'english'),
      (v_last + 4, '[시험용] 과학 프로젝트 자료 정리 마감',
                   '[시험용] 자료를 혼자 정리함', null,
                   '[시험용] 쓴 책과 자료를 정리하고 감',
                   '[시험용] 마감 전에 스스로 끝냄',
                   'done', 'self', 'none')
    ) as s(dt, school, academic, selfm, life, growth, hw, ind, cause)
    cross join lateral (select s.dt as dt) d
   where not exists (
     select 1 from public.daily_logs dl
      where dl.student_id = v_student and dl.date = s.dt
        and coalesce(dl.school_note,'') like '[시험용]%');

  raise notice '';
  raise notice '✅ 시험용 자료를 넣었습니다';
  raise notice '   학생: %  ·  학부모: %  ·  쓴 사람: %', v_sname, coalesce(v_pname,'(없음)'), v_tname;
  raise notice '   주간 피드백: % 와 % (둘 다 보냄 상태)', v_last, v_prev;
  raise notice '';
  raise notice '👉 % 님 계정으로 로그인 → 내 아이 → 📬 주간 피드백', coalesce(v_pname,'학부모');
end $$;

-- ── 무엇이 들어갔나 ───────────────────────────────────────────────
select m.name as "학생", f.week_start as "주", f.status as "상태",
       f.author_name as "쓴 사람",
       (select count(*) from public.weekly_feedback_comments c where c.feedback_id = f.id) as "댓글"
  from public.weekly_feedbacks f
  join public.members m on m.id = f.student_id
 where coalesce(f.summary,'') like '[시험용]%'
 order by f.week_start desc;

select m.name as "학생", d.date as "날짜", d.cause as "막힌 곳", d.homework as "숙제"
  from public.daily_logs d
  join public.members m on m.id = d.student_id
 where coalesce(d.school_note,'') like '[시험용]%'
 order by d.date;

-- 학부모가 열 링크 (아래 주소를 그 학부모께 보내면 됩니다)
select 'https://koreayjk.github.io/imessenger/index.html#pf=' || f.id as "학부모에게 보낼 링크",
       m.name as "학생", f.week_start as "주"
  from public.weekly_feedbacks f
  join public.members m on m.id = f.student_id
 where coalesce(f.summary,'') like '[시험용]%'
 order by f.week_start desc;

-- =====================================================================
--  🧹 확인이 끝나면 — 아래 세 줄을 복사해 실행하면 깨끗이 지워집니다
-- =====================================================================
--  delete from public.weekly_feedback_comments
--   where feedback_id in (select id from public.weekly_feedbacks where coalesce(summary,'') like '[시험용]%');
--  delete from public.weekly_feedbacks where coalesce(summary,'') like '[시험용]%';
--  delete from public.daily_logs      where coalesce(school_note,'') like '[시험용]%';
