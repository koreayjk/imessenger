-- =====================================================================
--  🔐 남은 표 잠그기 — 로그인 없이 읽히던 것들
--
--  무엇을 확인했나 (프로덕션에서 공개 anon 키로 직접 재현)
--   index.html 안의 공개 키 하나로 로그인 없이 이만큼 읽혔습니다.
--
--     message_reads     28,859행     messages            3,974행  ← 채팅 내용
--     channel_members      621행     message_reactions     253행
--     channels             218행     reading_books         159행
--     events               147행     tcs_records           112행  ← 생활기록부
--     reading_logs          46행     student_groups         13행
--     record_orgs           12행     daily_word              9행
--     schedule_images        8행     todos                   5행
--     announcements          1행     monthly_goals           1행
--
--   저장소가 공개라 키는 누구나 가져다 씁니다. 채팅 내용과 학생
--   생활기록부(이름·생년월일·주소·보호자 연락처)가 여기 들어 있습니다.
--
--  이 파일이 하는 일
--   표마다 '내 공동체 것만' 허용 정책을 먼저 만들고, 마지막에 RLS 를
--   켭니다. 순서가 중요하니 통째로 한 번에 실행해 주세요.
--   읽기만 막는 게 아니라 쓰기도 같은 기준으로 묶습니다 — 지금은 로그인만
--   하면 남의 공동체 채팅도 지울 수 있는 상태입니다.
--
--  일부러 열어 두는 것
--   · communities      — 가입 화면과 매점(store.html)에서 공동체를 골라야 합니다
--   · newsletters      — '공유' 켠 가정통신문만 (이미 그렇게 되어 있습니다)
--
--  앱이 깨지지 않는 근거 (코드를 따라가 확인했습니다)
--   · 로그인 전에 도는 길은 세 곳뿐입니다 — 가입 화면(communities),
--     공개 가정통신문(#nl=, newsletters), store.html(communities).
--     셋 다 위에서 열어 둡니다.
--   · 총관리자·부총관리자는 can_view_all_communities() 로 모든 공동체를
--     그대로 봅니다 (공동체 전환 기능).
--   · Edge Function 은 service_role 이라 RLS 를 통과합니다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================


-- ── 1. 도우미 ──
--  db/멤버_개인정보_보호_RLS.sql 과 db/부총관리자_DB설치.sql 에서 이미
--  만들었지만, 이 파일만 돌려도 되도록 같이 둡니다. (내용 동일)
create or replace function public.my_community_id()
returns uuid language sql security definer stable set search_path = public as $$
  select community_id from public.members where id = auth.uid();
$$;
create or replace function public.can_view_all_communities()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','vice_admin'));
$$;
grant execute on function public.my_community_id()         to authenticated;
grant execute on function public.can_view_all_communities() to authenticated;

-- 내 공동체인가 (총·부총관리자는 전부)
--  members 를 한 번만 본다. my_community_id() 와 can_view_all_communities() 를
--  둘 다 부르면 줄마다 두 번씩 들어가서, 메시지 4천 개를 여는 데 100ms 가 더 붙었다.
create or replace function public.mine_comm(cid uuid)
returns boolean language sql security definer stable parallel safe
set search_path = public as $$
  select exists (select 1 from public.members me
                  where me.id = auth.uid()
                    and (me.community_id = cid
                         or me.community_role in ('super_admin','vice_admin')));
$$;
grant execute on function public.mine_comm(uuid) to authenticated;

-- '내가 볼 수 있는 채팅방' 목록. 함수에 줄마다 다른 값을 넘기면 줄마다 다시
-- 도는데, 이렇게 두면 한 번 만들어 두고 모든 줄이 같이 쓴다.
create or replace function public.my_channel_ids()
returns setof uuid language sql security definer stable parallel safe
set search_path = public as $$
  select c.id from public.channels c
   where exists (select 1 from public.members me
                  where me.id = auth.uid()
                    and (me.community_id = c.community_id
                         or me.community_role in ('super_admin','vice_admin')));
$$;
grant execute on function public.my_channel_ids() to authenticated;

create or replace function public.my_message_ids()
returns setof uuid language sql security definer stable parallel safe
set search_path = public as $$
  select m.id from public.messages m
   where m.channel_id in (select public.my_channel_ids());
$$;
grant execute on function public.my_message_ids() to authenticated;


-- ── 2. 표마다 정책을 깔고 RLS 를 켠다 ──
--  표를 두 묶음으로 나눠 다룹니다. 섞으면 조용히 더 열리는 일이 생깁니다.
--
--  ⓐ 정책이 아예 없는 표 — 지금 RLS 가 꺼져 있어 누구나 다 읽습니다.
--     '내 공동체 것만' 정책을 새로 깔고 켭니다. 순수하게 조여집니다.
--
--  ⓑ 이미 제 정책을 가진 표 — RLS 만 꺼져 있어서 정책이 잠자고 있습니다.
--     (reading_books·todos 의 정책은 'to authenticated' 인데도 익명에게
--      159행·5행이 읽혔습니다. 정책이 아니라 RLS 가 꺼져 있던 겁니다)
--     여기는 정책을 건드리지 않고 RLS 만 켭니다. 허용 정책은 OR 로 합쳐지니,
--     기존 정책을 두고 새 정책을 더하면 오히려 더 열립니다.

create or replace function public._tcs_lock(tbl text, pred text)
returns text language plpgsql as $$
begin
  execute format('alter table public.%I enable row level security', tbl);
  if pred is not null then
    execute format('drop policy if exists %I on public.%I', tbl || '_comm', tbl);
    execute format(
      'create policy %I on public.%I for all to authenticated using (%s) with check (%s)',
      tbl || '_comm', tbl, pred, pred);
  end if;
  execute format('grant select, insert, update, delete on public.%I to authenticated', tbl);
  return tbl || (case when pred is null then ' (RLS 만 켬 — 제 정책 유지)' else '' end);
exception when undefined_table then
  return tbl || ' — 표가 없어 건너뜀';
end $$;

-- ⓐ community_id 를 직접 가진 표
select public._tcs_lock(t, 'public.mine_comm(community_id)') as "잠근 표"
  from unnest(array[
    'channels','tcs_records','events','reading_logs',
    'daily_word','announcements','monthly_goals','schedule_images',
    'student_groups','record_orgs'
  ]) t
union all
-- ⓐ 채팅방을 거쳐 공동체를 찾는 표
select public._tcs_lock(t, 'channel_id in (select public.my_channel_ids())')
  from unnest(array['messages','channel_members']) t
union all
-- ⓐ 메시지를 거쳐 찾는 표
select public._tcs_lock(t, 'message_id in (select public.my_message_ids())')
  from unnest(array['message_reads','message_reactions']) t
union all
-- ⓑ 제 정책이 있는 표 — RLS 만 켠다
select public._tcs_lock(t, null)
  from unnest(array['channel_reads','poll_votes','channel_groups','reading_notes','reading_books','todos']) t;

drop function if exists public._tcs_lock(text, text);

-- 할 일은 공동체 칸이 있는데 정책이 'to authenticated using(true)' 라
-- 로그인만 하면 남의 공동체 할 일까지 보입니다. 그 한 줄만 조입니다.
-- (나머지 정책 — 본인이 만든 것만 등록·수정 — 은 그대로 둡니다)
drop policy if exists todos_select on public.todos;
create policy todos_select on public.todos for select to authenticated
  using (public.mine_comm(community_id));

-- 필독서 목록은 공동체 구분이 없는 공용 자료입니다. 로그인한 사람 모두가
-- 보는 게 맞아서 그대로 둡니다 (reading_books_select_all).

-- ── 3. 찾는 속도 — 정책이 매 줄마다 타고 들어가는 길에 색인을 둔다 ──
create index if not exists messages_channel_idx        on public.messages (channel_id);
create index if not exists channel_members_ch_idx      on public.channel_members (channel_id);
create index if not exists message_reads_msg_idx       on public.message_reads (message_id);
create index if not exists message_reactions_msg_idx   on public.message_reactions (message_id);
create index if not exists channels_comm_idx           on public.channels (community_id);

notify pgrst, 'reload schema';


-- ── 4. 확인 ──
select c.relname as "표",
       case when c.relrowsecurity then '🔒 켜짐' else '⚠️ 꺼짐' end as "RLS",
       (select count(*) from pg_policy p where p.polrelid = c.oid) as "정책 수"
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('channels','messages','channel_members','message_reads','message_reactions',
                     'channel_reads','channel_groups','poll_votes','tcs_records','events',
                     'reading_books','reading_logs','reading_notes','todos','daily_word',
                     'announcements','monthly_goals','schedule_images','student_groups','record_orgs',
                     'communities','newsletters','members')
 order by 2, 1;


-- =====================================================================
--  ✅ 실행한 뒤 이것만 눌러봐 주세요 (5분)
--
--   1. 시크릿 창으로 앱 열기 → 로그인 되나
--   2. 채팅 — 방 목록 · 지난 대화 · 사진 · 읽음 표시 · 이모지
--   3. 새 메시지 보내기 / 지우기
--   4. 일정 — 달력에 일정이 보이나 / 일정 추가
--   5. 학사 → 생기부 — 학생 기록이 보이나 / 저장되나
--   6. 홈 — 공지·오늘의 말씀·이달의 목표·사진 위젯
--   7. 트리플스쿨 — 필독서 목록 · 독후감
--   8. 총관리자로 공동체 전환 → 그 공동체 채팅이 보이나
--   9. 새 계정 가입 (공동체 목록이 뜨나)
--
--  ❗ 하나라도 안 되면 그 표만 즉시 되돌립니다. 예를 들어 채팅이 막혔다면:
--
--       alter table public.messages          disable row level security;
--       alter table public.message_reads     disable row level security;
--       alter table public.message_reactions disable row level security;
--
--     전부 되돌리려면 (이 파일이 새로 켠 표만):
--       do $$ declare r record; begin
--         for r in select unnest(array['channels','messages','channel_members','message_reads',
--           'message_reactions','tcs_records','events','reading_logs','daily_word','announcements',
--           'monthly_goals','schedule_images','student_groups','record_orgs']) as t loop
--           execute format('alter table public.%I disable row level security', r.t);
--         end loop; end $$;
--
--     되돌린 뒤 어디가 막혔는지 알려주시면 그 조건만 고쳐 드리겠습니다.
--     (정책은 남겨 둬도 RLS 가 꺼져 있으면 아무 영향이 없습니다)
-- =====================================================================
