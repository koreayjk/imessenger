-- =====================================================================
--  💾 저장 용량 — 올린 파일을 보고 지우기
--
--  지금까지는 '어디에 얼마나 쓰는지' 만 보였습니다. 정작 **무엇이**
--  자리를 차지하는지는 볼 수가 없어서, 가득 찼을 때 치울 길이 없었습니다.
--  이 파일은 셋을 더합니다.
--
--    ① storage_file_community(이름)   파일 하나가 어느 공동체 것인지
--    ② community_storage_files(…)     그 공동체가 올린 파일 목록
--    ③ storage.objects 에 지우기 정책  공동체를 맡은 분만, 제 공동체 것만
--
--  ⚠️ 지우면 되돌릴 수 없습니다. 채팅에 올린 사진을 지우면 그 채팅에서는
--     깨진 그림으로 보입니다. 화면에서 그렇게 적어 두었습니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
--  먼저 db/공동체_저장용량_DB설치.sql 을 실행해 두셔야 합니다.
-- =====================================================================

-- ── ① 파일 하나가 어느 공동체 것인가 ─────────────────────────────
--  storage_owner_community() 는 경로에 공동체가 **직접** 박힌 것만 봅니다.
--  채팅(chat/<채널>)과 개인 폴더(notes·signatures·mockexam/<사람>)는
--  한 번 더 찾아봐야 알 수 있습니다. 세 곳에 같은 식을 베껴 두면 반드시
--  어긋나므로, 한 군데로 모읍니다.
create or replace function public.storage_file_community(obj_name text)
returns uuid language sql stable security definer
set search_path = public as $$
  select coalesce(
    public.storage_owner_community(obj_name),
    case when split_part(obj_name,'/',1) = 'chat'
         then (select c.community_id from public.channels c
                where c.id::text = split_part(obj_name,'/',2)) end,
    case when split_part(obj_name,'/',1) in ('notes','signatures','mockexam')
         then (select m.community_id from public.members m
                where m.id::text = split_part(obj_name,'/',2)) end
  );
$$;
grant execute on function public.storage_file_community(text) to authenticated;


-- ── 갈래 이름 (화면과 같은 말을 쓴다) ────────────────────────────
create or replace function public.storage_kind_label(top text)
returns text language sql immutable as $$
  select case top
    when 'chat'       then '채팅 사진·파일'
    when 'approvals'  then '전자결재 첨부'
    when 'students'   then '학생 증명사진'
    when 'notes'      then 'IM노트 첨부'
    when 'training'   then '사역자교육 표지'
    when 'orgs'       then '기관 로고'
    when 'community'  then '공동체 로고'
    when 'seals'      then '직인'
    when 'signatures' then '개인 서명'
    when 'mockexam'   then '모의고사 답안'
    else top end;
$$;
grant execute on function public.storage_kind_label(text) to authenticated;


-- ── ①-2 방(채널)마다 얼마나 쓰고 있나 ──────────────────────────
--  채팅 사진·파일이 거의 전부를 차지합니다. 그런데 '채팅 2.87GB' 로만
--  보여서는 어느 방을 치워야 할지 알 수가 없습니다.
--  ⚠️ 돌려주는 칸이 바뀌면 create or replace 가 **거부합니다.** 그런데 거부만
--    하고 멈추지 않아서, 옛 몸통이 그대로 남은 채로 설치가 끝납니다.
--    (재 보고 알았습니다 — 칸을 늘렸는데 옛것이 계속 돌고 있었습니다)
--    칸을 바꿀 때마다 서명이 늘어나 하나씩 적어 두면 또 어긋나므로,
--    이름이 같은 것은 모두 지웁니다.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig
             from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and p.proname in ('community_storage_rooms','community_storage_files')
  loop execute 'drop function ' || r.sig; end loop;
end $$;

create or replace function public.community_storage_rooms(cid uuid default null)
returns table ("방" uuid, "방이름" text, "방종류" text, "사용 바이트" bigint, "파일 수" bigint)
language plpgsql security definer stable
set search_path = public, storage as $$
declare target uuid := coalesce(cid, public.my_community_id());
begin
  if target is null then return; end if;
  if target <> public.my_community_id() and not public.can_view_all_communities() then return; end if;
  if not exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','vice_admin','community_admin')) then
    return;
  end if;

  return query
  select c.id, c.name, c.kind,
         coalesce(sum(coalesce(nullif(o.metadata->>'size','')::bigint, 0)), 0)::bigint,
         count(o.id)::bigint
    from public.channels c
    join storage.objects o
      on o.bucket_id = 'messenger'
     and split_part(o.name,'/',1) = 'chat'
     and split_part(o.name,'/',2) = c.id::text
   where c.community_id = target
   group by c.id, c.name, c.kind
  having count(o.id) > 0
   order by 4 desc;
end $$;
grant execute on function public.community_storage_rooms(uuid) to authenticated;


-- ── ② 올린 파일 목록 ─────────────────────────────────────────────
--  sort: 'big' 큰 것부터 (자리를 치우려면 이쪽) · 'new' 새것부터
--  room: 채널 하나만 보고 싶을 때
create or replace function public.community_storage_files(
  cid   uuid default null,
  kind  text default null,
  sort  text default 'big',
  lim   int  default 60,
  off   int  default 0,
  room  uuid default null
)
returns table ("경로" text, "폴더" text, "갈래" text,
               "크기" bigint, "형식" text, "올린때" timestamptz,
               "방" uuid, "방이름" text, "방종류" text)
language plpgsql security definer stable
set search_path = public, storage as $$
declare target uuid := coalesce(cid, public.my_community_id());
begin
  if target is null then return; end if;
  --  남의 공동체 파일은 총·부총관리자만 봅니다.
  if target <> public.my_community_id() and not public.can_view_all_communities() then return; end if;
  --  보는 것도 공동체를 맡은 사람만. 학생·학부모가 남이 올린 파일
  --  목록을 훑을 까닭이 없습니다.
  if not exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','vice_admin','community_admin')) then
    return;
  end if;

  return query
  select o.name,
         split_part(o.name,'/',1),
         public.storage_kind_label(split_part(o.name,'/',1)),
         coalesce(nullif(o.metadata->>'size','')::bigint, 0),
         coalesce(o.metadata->>'mimetype',''),
         o.created_at,
         ch.id,
         ch.name,
         ch.kind
    from storage.objects o
    left join public.channels ch
      on split_part(o.name,'/',1) = 'chat'
     and ch.id::text = split_part(o.name,'/',2)
   where o.bucket_id = 'messenger'
     --  ⚠️ 맨 이름으로 쓰면 안 됩니다. channels 를 붙인 뒤로는 그 표의
     --     칸(kind · sort · name …)과 이름이 부딪혀
     --     'column reference ... is ambiguous' 로 **목록이 통째로 안 나옵니다.**
     --     두 번 데었습니다(kind, 그 다음 sort). 그래서 이제 파라미터는
     --     하나도 빼지 않고 전부 함수 이름을 앞에 붙여 가립니다.
     and (community_storage_files.kind is null
          or split_part(o.name,'/',1) = community_storage_files.kind)
     and (community_storage_files.room is null or ch.id = community_storage_files.room)
     and public.storage_file_community(o.name) = target
   order by case when community_storage_files.sort = 'new' then o.created_at end desc nulls last,
            case when community_storage_files.sort <> 'new'
                 then coalesce(nullif(o.metadata->>'size','')::bigint, 0) end desc nulls last
   limit greatest(1, least(coalesce(community_storage_files.lim, 60), 200))
  offset greatest(0, coalesce(community_storage_files.off, 0));
end $$;
grant execute on function public.community_storage_files(uuid, text, text, int, int, uuid) to authenticated;


-- ── ③ 지울 수 있는 사람인가 ──────────────────────────────────────
--  공동체를 맡은 사람이, 제 공동체 파일만. 총·부총관리자는 전부.
create or replace function public.can_delete_storage_file(obj_name text)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.members me
     where me.id = auth.uid()
       and me.community_role in ('super_admin','vice_admin','community_admin')
       and ( me.community_role in ('super_admin','vice_admin')
             or me.community_id = public.storage_file_community(obj_name) )
  );
$$;
grant execute on function public.can_delete_storage_file(text) to authenticated;

--  저장소에 지우기 정책을 답니다. 이것이 없으면 화면에서 눌러도
--  오류 없이 그냥 아무 일도 안 일어납니다 (RLS 는 0줄을 돌려줍니다).
drop policy if exists "관리자는 제 공동체 파일을 지울 수 있다" on storage.objects;
create policy "관리자는 제 공동체 파일을 지울 수 있다"
  on storage.objects for delete to authenticated
  using ( bucket_id = 'messenger' and public.can_delete_storage_file(name) );

notify pgrst, 'reload schema';


-- ── 확인 ─────────────────────────────────────────────────────────
--  방마다 얼마나 쓰고 있나
select "방이름", round(("사용 바이트"/1048576.0)::numeric, 1) as "MB", "파일 수"
  from public.community_storage_rooms();

--  내 공동체에서 가장 자리를 많이 차지하는 파일 열 개
select "갈래", "방이름", "경로", round(("크기"/1048576.0)::numeric, 2) as "MB", "올린때"
  from public.community_storage_files(null, null, 'big', 10, 0, null);

--  지우기 정책이 달렸나
select policyname as "정책", cmd as "대상"
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects' and cmd = 'DELETE';
