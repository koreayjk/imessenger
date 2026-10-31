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


-- ── ② 올린 파일 목록 ─────────────────────────────────────────────
--  sort: 'big' 큰 것부터 (자리를 치우려면 이쪽) · 'new' 새것부터
create or replace function public.community_storage_files(
  cid   uuid default null,
  kind  text default null,
  sort  text default 'big',
  lim   int  default 60,
  off   int  default 0
)
returns table ("경로" text, "폴더" text, "갈래" text,
               "크기" bigint, "형식" text, "올린때" timestamptz)
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
         o.created_at
    from storage.objects o
   where o.bucket_id = 'messenger'
     and (kind is null or split_part(o.name,'/',1) = kind)
     and public.storage_file_community(o.name) = target
   order by case when sort = 'new' then o.created_at end desc nulls last,
            case when sort <> 'new'
                 then coalesce(nullif(o.metadata->>'size','')::bigint, 0) end desc nulls last
   limit greatest(1, least(coalesce(lim, 60), 200))
  offset greatest(0, coalesce(off, 0));
end $$;
grant execute on function public.community_storage_files(uuid, text, text, int, int) to authenticated;


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
--  내 공동체에서 가장 자리를 많이 차지하는 파일 열 개
select "갈래", "경로", round(("크기"/1048576.0)::numeric, 2) as "MB", "올린때"
  from public.community_storage_files(null, null, 'big', 10, 0);

--  지우기 정책이 달렸나
select policyname as "정책", cmd as "대상"
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects' and cmd = 'DELETE';
