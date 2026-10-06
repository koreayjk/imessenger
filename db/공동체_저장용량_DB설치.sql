-- =====================================================================
--  💾 공동체별 저장 용량
--
--  지금은 모든 공동체가 한 창고를 같이 씁니다. 한 곳이 다 써 버리면
--  나머지도 같이 막힙니다. (지금 IM USA 가 전체의 98.9% 를 쓰고 있습니다)
--  그래서 공동체마다 쓸 수 있는 양을 정해 둡니다. 기본 5GB.
--
--  어떻게 세나
--   따로 숫자를 적어 두고 더하고 빼는 방식은 쓰지 않습니다. 업로드가
--   실패하거나 파일을 직접 지우면 금세 실제와 어긋나기 때문입니다.
--   저장소 목록(storage.objects)을 그때그때 세어 실제 값을 돌려줍니다.
--
--  파일 경로에서 공동체를 알아냅니다.
--    chat/<채널>/…        → 그 채널의 공동체
--    approvals·orgs·seals·students·training·community/<공동체>/…
--    notes·signatures·mockexam/<사람>/…  → 그 사람의 공동체
--    schedule/…           → 공동체를 알 수 없음 (전체 공용, 지금 4MB)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

alter table public.communities
  add column if not exists storage_quota_mb int not null default 5120;

comment on column public.communities.storage_quota_mb is
  '이 공동체가 쓸 수 있는 저장 용량(MB). 0 이면 무제한.';


-- ── 파일 하나가 어느 공동체 것인지 ──
create or replace function public.storage_owner_community(obj_name text)
returns uuid language sql immutable set search_path = public as $$
  select case
    when split_part(obj_name,'/',1) in
         ('approvals','orgs','seals','students','training','community')
         and split_part(obj_name,'/',2) ~ '^[0-9a-fA-F-]{36}$'
      then split_part(obj_name,'/',2)::uuid
    else null
  end;
$$;


-- ── 공동체별 사용량 ──
--  security definer 라 storage.objects 를 읽을 수 있습니다.
--  보기 권한은 아래에서 따로 가립니다.
create or replace function public.community_storage_usage()
returns table ("공동체" uuid, "이름" text, "사용 바이트" bigint, "한도 MB" int)
language sql security definer stable set search_path = public, storage as $$
  with obj as (
    select o.name,
           coalesce(nullif(o.metadata->>'size','')::bigint, 0) as sz,
           split_part(o.name,'/',1) as top,
           split_part(o.name,'/',2) as sub
      from storage.objects o
     where o.bucket_id = 'messenger'
  ),
  mapped as (
    select coalesce(
             public.storage_owner_community(o.name),
             case when o.top = 'chat'
                  then (select c.community_id from public.channels c
                         where c.id::text = o.sub) end,
             case when o.top in ('notes','signatures','mockexam')
                  then (select m.community_id from public.members m
                         where m.id::text = o.sub) end
           ) as cid,
           o.sz
      from obj o
  )
  select c.id, c.name,
         coalesce((select sum(m.sz) from mapped m where m.cid = c.id), 0)::bigint,
         c.storage_quota_mb
    from public.communities c
   order by 3 desc;
$$;
grant execute on function public.community_storage_usage() to authenticated;

-- 한 공동체만 — 올리기 전에 확인할 때 쓴다.
-- 자기 공동체는 누구나, 남의 공동체는 총·부총관리자만.
create or replace function public.community_storage_one(cid uuid default null)
returns table ("사용 바이트" bigint, "한도 MB" int, "볼 수 있음" boolean)
language plpgsql security definer stable set search_path = public, storage as $$
declare target uuid := coalesce(cid, public.my_community_id());
begin
  if target is null then
    return query select 0::bigint, 0, false; return;
  end if;
  if target <> public.my_community_id() and not public.can_view_all_communities() then
    return query select 0::bigint, 0, false; return;
  end if;
  return query
    select u."사용 바이트", u."한도 MB", true
      from public.community_storage_usage() u
     where u."공동체" = target;
end $$;
grant execute on function public.community_storage_one(uuid) to authenticated;

-- 한 공동체가 '어디에' 쓰고 있는지 — 관리 화면에서 보여 준다
create or replace function public.community_storage_detail(cid uuid default null)
returns table ("갈래" text, "사용 바이트" bigint, "파일 수" bigint)
language plpgsql security definer stable set search_path = public, storage as $$
declare target uuid := coalesce(cid, public.my_community_id());
begin
  if target is null then return; end if;
  if target <> public.my_community_id() and not public.can_view_all_communities() then return; end if;

  return query
  with obj as (
    select o.name,
           coalesce(nullif(o.metadata->>'size','')::bigint, 0) as sz,
           split_part(o.name,'/',1) as top,
           split_part(o.name,'/',2) as sub
      from storage.objects o
     where o.bucket_id = 'messenger'
  ),
  mine as (
    select o.top, o.sz from obj o
     where coalesce(
             public.storage_owner_community(o.name),
             case when o.top = 'chat'
                  then (select c.community_id from public.channels c where c.id::text = o.sub) end,
             case when o.top in ('notes','signatures','mockexam')
                  then (select m.community_id from public.members m where m.id::text = o.sub) end
           ) = target
  )
  select case m.top
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
           else m.top
         end,
         sum(m.sz)::bigint,
         count(*)::bigint
    from mine m
   group by 1
   order by 2 desc;
end $$;
grant execute on function public.community_storage_detail(uuid) to authenticated;


notify pgrst, 'reload schema';


-- ── 지금 상태 ──
select "이름"                                                as "공동체",
       round(("사용 바이트" / 1048576.0)::numeric, 1)         as "사용 MB",
       "한도 MB",
       case when "한도 MB" = 0 then '무제한'
            else round(("사용 바이트" / 1048576.0 / "한도 MB" * 100)::numeric, 1) || '%' end as "쓴 비율"
  from public.community_storage_usage();

-- =====================================================================
--  한도를 바꾸려면
--    관리 → 공동체 에서 공동체별로 정할 수 있습니다 (총관리자).
--    SQL 로 한 번에 바꾸려면:
--      update public.communities set storage_quota_mb = 10240;   -- 전부 10GB
--      update public.communities set storage_quota_mb = 0        -- 무제한
--       where name = 'IM USA';
--
--  한도를 넘으면 그 공동체에서는 새 파일이 올라가지 않습니다.
--  이미 올라간 파일은 그대로 있고, 채팅·보기는 아무 영향 없습니다.
-- =====================================================================
