-- ════════════════════════════════════════════════════════════════════
--  🔒 채팅방 권한 잠그기
--
--  왜:  "학생이 1:1이 아닌 그룹방을 만들면 거기에 다른 사람을 초대해서
--        대화가 가능한 거 같은데 이거 체크해줘"
--
--  맞습니다. 그리고 생각하신 것보다 넓게 열려 있었습니다.
--  지역 데이터베이스에 지금 정책을 그대로 깔고 학생으로 로그인해서
--  여덟 가지를 해봤더니 — 여덟 가지 다 됐습니다.
--
--    ① 내가 없는 방(교사 전용방·남의 1:1)이 목록에 다 보인다
--    ② 남의 1:1 대화 내용이 그대로 읽힌다
--    ③ 학생이 그룹방을 만들 수 있다
--    ④ 거기에 다른 학생을 초대할 수 있다        ← 물어보신 것
--    ⑤ 내가 없는 교사 전용방에 나를 밀어넣을 수 있다
--    ⑥ 남의 1:1 방에 글을 쓸 수 있다
--    ⑦ 선생님을 교사 전용방에서 내쫓을 수 있다
--    ⑧ 교사 전용방을 통째로 지울 수 있다
--
--  화면에서는 ③④만 눈에 띄지만, 나머지도 브라우저 주소창에서 바로
--  됩니다. '학생끼리는 1:1 대화를 할 수 없어요' 는 화면에만 적혀
--  있었을 뿐, 데이터베이스는 아무것도 막고 있지 않았습니다.
--
--  까닭:  my_channel_ids() 가 '같은 공동체의 모든 방' 을 돌려줬습니다.
--         이름이 '내 채팅방' 인데 내용은 '우리 공동체 전체 방' 이었고,
--         메시지·채널멤버 정책이 모두 이 함수에 기대고 있었습니다.
--
--  고친 뒤:
--         my_channel_ids() = 내가 실제로 들어가 있는 방
--                            (+ 총·부총관리자는 지켜보려고 전부)
--         방 목록은 간사 이상이 보되, 대화 내용은 들어가 있는 사람만.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

-- ── 0. 기대는 도우미가 없으면 여기서 만든다 ───────────────────────
--  db/신고차단_DB설치.sql 을 먼저 돌리셨으면 이미 있습니다. 같은 내용입니다.
create or replace function public.staff_of(cid uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_role in ('super_admin','vice_admin')
          or ( me.community_id = cid
               and me.community_role in ('community_admin','admin_officer','teacher','staff') ) )
  );
$$;
grant execute on function public.staff_of(uuid) to authenticated;

create or replace function public.can_moderate_channel(ch uuid) returns boolean
language sql stable security definer parallel safe set search_path = public as $$
  select exists (select 1 from public.channels c
                  where c.id = ch and public.staff_of(c.community_id));
$$;
grant execute on function public.can_moderate_channel(uuid) to authenticated;

--  mine_comm 도 없을 수 있습니다 (db/전체잠그기_RLS.sql 을 안 돌리신 경우).
create or replace function public.mine_comm(cid uuid)
returns boolean language sql security definer stable parallel safe
set search_path = public as $$
  select exists (select 1 from public.members me
                  where me.id = auth.uid()
                    and coalesce(me.status, 'active') <> 'removed'
                    and (me.community_id = cid
                         or me.community_role in ('super_admin','vice_admin')));
$$;
grant execute on function public.mine_comm(uuid) to authenticated;


-- ── 1. 방을 만든 사람을 적어 둔다 ─────────────────────────────────
--  1:1 방을 만드는 그 한순간에는 아직 멤버 줄이 없습니다. 만든 사람을
--  적어두지 않으면, 방을 만들자마자 자기 방이 안 보이게 됩니다.
alter table public.channels add column if not exists created_by uuid;

do $$ begin
  -- 기본값을 '지금 로그인한 사람' 으로. 화면 코드를 안 고쳐도 채워집니다.
  begin
    alter table public.channels alter column created_by set default auth.uid();
  exception when others then null;   -- auth.uid() 가 없는 환경이면 건너뛴다
  end;
end $$;

create index if not exists channels_created_by_idx on public.channels (created_by);
create index if not exists channel_members_member_idx on public.channel_members (member_id);


-- ── 2. '내 채팅방' 을 진짜 내 채팅방으로 ──────────────────────────
--  총관리자·부총관리자는 그대로 전부 봅니다 (지켜보라고 있는 자리입니다).
--  나머지는 내가 들어가 있는 방 + 방금 내가 만든 방.
--
--  security definer 라서 이 안에서 channel_members 를 읽는 것은
--  정책에 걸리지 않습니다. 정책이 이 함수를 다시 부르는 돌림이 생기지 않습니다.
create or replace function public.my_channel_ids()
returns setof uuid language sql security definer stable parallel safe
set search_path = public as $$
  select c.id
    from public.channels c
   where exists (
     select 1 from public.members me
      where me.id = auth.uid()
        and coalesce(me.status, 'active') <> 'removed'
        and ( me.community_role in ('super_admin','vice_admin')
           or c.created_by = me.id
           or exists (select 1 from public.channel_members cm
                       where cm.channel_id = c.id and cm.member_id = me.id) ));
$$;
grant execute on function public.my_channel_ids() to authenticated;


-- ── 3. 누구와 1:1 을 틀 수 있나 ───────────────────────────────────
--  채팅방 규칙 그대로입니다 — 학생끼리는 안 됩니다. 그 규칙이 지금까지
--  화면에만 적혀 있었습니다. 여기로 옮깁니다.
create or replace function public.can_dm(p_other uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1
      from public.members me
      join public.members o on o.id = p_other
     where me.id = auth.uid()
       and me.id <> o.id
       and coalesce(o.status,  'active') <> 'removed'
       and coalesce(me.status, 'active') <> 'removed'
       and ( me.community_id = o.community_id
             or me.community_role in ('super_admin','vice_admin') )
       -- 학생 × 학생 은 막는다. role 이 비어 있을 수 있으니 coalesce —
       -- NULL = '학생' 은 거짓이 아니라 '모름' 이라서 조건 전체를 망칩니다.
       and not ( (coalesce(me.community_role,'') = 'student' or coalesce(me.role,'') = '학생')
                 and (coalesce(o.community_role,'') = 'student' or coalesce(o.role,'') = '학생') )
       and coalesce(o.community_role,'') <> 'store_bot'
  );
$$;
grant execute on function public.can_dm(uuid) to authenticated;


-- ── 4. 방 ─────────────────────────────────────────────────────────
--  읽기 : 내가 들어간 방 + 간사 이상은 '단체방 목록' 까지 (내용은 아래 6번).
--         1:1 방은 목록조차 안 보입니다 — 누가 누구와 이야기하는지가
--         이미 사생활입니다. 총·부총관리자만 지켜봅니다.
--  만들기: 간사 이상은 자유롭게. 그 밖에는 1:1 방만, 내 이름으로.
--  고치기·지우기: 간사 이상만.
alter table public.channels enable row level security;
drop policy if exists channels_comm   on public.channels;
drop policy if exists channels_select on public.channels;
drop policy if exists channels_insert on public.channels;
drop policy if exists channels_update on public.channels;
drop policy if exists channels_delete on public.channels;

create policy channels_select on public.channels for select to authenticated
using ( id in (select public.my_channel_ids())
        or ( public.staff_of(community_id) and coalesce(kind,'topic') <> 'dm' ) );

create policy channels_insert on public.channels for insert to authenticated
with check (
  public.mine_comm(community_id)
  and ( public.staff_of(community_id)
        or ( coalesce(kind,'topic') = 'dm' and coalesce(created_by, auth.uid()) = auth.uid() ) )
);

create policy channels_update on public.channels for update to authenticated
using ( public.staff_of(community_id) ) with check ( public.staff_of(community_id) );

create policy channels_delete on public.channels for delete to authenticated
using ( public.staff_of(community_id) );

grant select, insert, update, delete on public.channels to authenticated;


-- ── 5. 방 멤버 ────────────────────────────────────────────────────
create or replace function public.can_add_channel_member(p_channel uuid, p_member uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1 from public.channels c
     where c.id = p_channel
       and ( public.staff_of(c.community_id)
             -- 1:1 방: 내가 만든 방에, 나와 상대만.
             or ( coalesce(c.kind,'topic') = 'dm'
                  and c.created_by = auth.uid()
                  and ( p_member = auth.uid() or public.can_dm(p_member) ) ) ));
$$;
grant execute on function public.can_add_channel_member(uuid, uuid) to authenticated;

alter table public.channel_members enable row level security;
drop policy if exists channel_members_comm   on public.channel_members;
drop policy if exists channel_members_select on public.channel_members;
drop policy if exists channel_members_insert on public.channel_members;
drop policy if exists channel_members_update on public.channel_members;
drop policy if exists channel_members_delete on public.channel_members;

create policy channel_members_select on public.channel_members for select to authenticated
using ( channel_id in (select public.my_channel_ids())
        or exists (select 1 from public.channels c
                    where c.id = channel_id
                      and coalesce(c.kind,'topic') <> 'dm'
                      and public.staff_of(c.community_id)) );

create policy channel_members_insert on public.channel_members for insert to authenticated
with check ( public.can_add_channel_member(channel_id, member_id) );

-- 즐겨찾기(★)는 내 줄만 건드립니다.
create policy channel_members_update on public.channel_members for update to authenticated
using      ( member_id = auth.uid() or public.can_moderate_channel(channel_id) )
with check ( member_id = auth.uid() or public.can_moderate_channel(channel_id) );

-- 내보내기는 간사 이상. 내가 나가는 것은 언제든.
create policy channel_members_delete on public.channel_members for delete to authenticated
using ( member_id = auth.uid() or public.can_moderate_channel(channel_id) );

grant select, insert, update, delete on public.channel_members to authenticated;

-- 1:1 방은 둘까지. 한 문장에 여러 줄을 밀어넣는 길을 막습니다
-- (정책의 count 는 문장 시작 시점을 보기 때문에 같은 문장 안의 줄을 못 셉니다.
--  방아쇠는 줄마다 그 자리에서 돌아서, 앞줄이 들어간 것을 봅니다.)
create or replace function public.dm_two_people() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text; n int;
begin
  select coalesce(kind,'topic') into k from public.channels where id = new.channel_id;
  if k <> 'dm' then return new; end if;
  select count(distinct member_id) into n from public.channel_members where channel_id = new.channel_id;
  if n >= 2 and not exists (select 1 from public.channel_members
                             where channel_id = new.channel_id and member_id = new.member_id) then
    raise exception '1:1 대화방에는 두 사람까지만 들어갈 수 있습니다';
  end if;
  return new;
end $$;

drop trigger if exists dm_two_people_trg on public.channel_members;
create trigger dm_two_people_trg before insert on public.channel_members
  for each row execute function public.dm_two_people();


-- ── 6. 메시지 ─────────────────────────────────────────────────────
--  정책 글은 그대로입니다. my_channel_ids() 가 좁아졌으니 같이 좁아집니다.
--  간사 이상이라도 '들어가 있지 않은 방' 의 대화는 못 읽습니다.
--  (총·부총관리자만 지켜봅니다 — 그게 지금까지의 약속이었습니다)
--  혹시 예전 정책이 남아 있으면 지웁니다. 허용 정책은 OR 로 합쳐져서,
--  하나만 남아 있어도 다 열립니다.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
            where schemaname='public' and tablename='messages'
  loop execute format('drop policy if exists %I on public.messages', p.policyname); end loop;
end $$;

alter table public.messages enable row level security;

--  한 군데만 더 엽니다: 신고된 메시지.
--  교직원이 신고함에서 처리하려면 그 한 줄은 읽을 수 있어야 합니다.
--  (가리기·지우기의 RETURNING 도 읽기 정책을 탑니다 — 안 열면 '권한이 없어요'
--   만 뜨고 신고 처리가 통째로 막힙니다. 지역에서 확인했습니다)
--  '들어가 있지 않은 방의 메시지' 중 읽히는 것은 '누군가 신고한 줄' 뿐입니다.
--  '신고된 줄인가' 는 definer 함수로 묻습니다. 정책 안에서 신고표를 직접
--  읽으면 그 표의 권한·정책에 또 매이고, 한쪽을 고칠 때 다른 쪽이 조용히
--  망가집니다. 묻는 길을 하나로 둡니다.
create or replace function public.is_reported_message(p_msg uuid)
returns boolean language plpgsql stable security definer parallel safe
set search_path = public as $$
begin
  if to_regclass('public.message_reports') is null then return false; end if;
  return exists (select 1 from public.message_reports r where r.message_id = p_msg);
end $$;
grant execute on function public.is_reported_message(uuid) to authenticated;

create policy messages_select on public.messages for select to authenticated
using ( channel_id in (select public.my_channel_ids())
        or ( public.can_moderate_channel(channel_id)
             and public.is_reported_message(id) ) );

create policy messages_insert on public.messages for insert to authenticated
with check ( sender_id = auth.uid() and channel_id in (select public.my_channel_ids()) );

create policy messages_update on public.messages for update to authenticated
using      ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) )
with check ( public.can_moderate_channel(channel_id)
             or (sender_id = auth.uid() and hidden_at is null) );

create policy messages_delete on public.messages for delete to authenticated
using ( public.can_moderate_channel(channel_id)
        or (sender_id = auth.uid() and hidden_at is null) );

grant select, insert, update, delete on public.messages to authenticated;


-- ── 7. 지금 있는 방의 '만든 사람' 메우기 ──────────────────────────
--  옛날 방에는 created_by 가 비어 있습니다. 비어 있어도 2번 함수가
--  멤버 줄로 찾으니 문제는 없지만, 1:1 방만 첫 멤버로 메워 둡니다.
update public.channels c
   set created_by = (select cm.member_id from public.channel_members cm
                      where cm.channel_id = c.id order by cm.ctid limit 1)
 where c.created_by is null and coalesce(c.kind,'topic') = 'dm';

notify pgrst, 'reload schema';

-- ── 확인 ──────────────────────────────────────────────────────────
select tablename as "표", policyname as "정책", cmd as "무엇"
  from pg_policies
 where schemaname = 'public'
   and tablename in ('channels','channel_members','messages')
 order by tablename, cmd, policyname;
