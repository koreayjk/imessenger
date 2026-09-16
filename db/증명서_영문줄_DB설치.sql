-- ═══════════════════════════════════════════════════════════════
--  증명서 — 제목 아래 작은 영문 줄(부제)을 직접 정할 수 있게
--
--  직접입력 증명서에서 제목뿐 아니라 그 아래 줄(기본값 CERTIFICATE)도
--  바꿀 수 있게 합니다. 발급 대장에서 다시 뽑을 때 그때 찍힌 그대로
--  나와야 하므로 대장에도 같이 남깁니다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 [Run] 한 번이면 끝납니다.
--  여러 번 실행해도 안전합니다.
--  ※ db/증명서_발급대장_직인_DB설치.sql 을 먼저 실행해 두셔야 합니다.
-- ═══════════════════════════════════════════════════════════════

alter table public.certificates
  add column if not exists doc_sub text;

comment on column public.certificates.doc_sub is
  '증서 제목 아래 작은 줄. 비어 있으면 종류의 기본값(CERTIFICATE 등)';

-- 발급 함수에 doc_sub 한 줄만 더한다. 나머지는 그대로다.
create or replace function public.issue_certificate(p jsonb)
returns public.certificates
language plpgsql security definer set search_path = public as $$
declare
  cid uuid;
  idt date := coalesce((p->>'issue_date')::date, current_date);
  yr  int  := extract(year from idt)::int;
  n   int;
  no  text;
  rec public.certificates;
begin
  if not public.is_cert_issuer() then
    raise exception '증명서를 발급할 권한이 없습니다.' using errcode = '42501';
  end if;

  -- 이 함수는 security definer 라 RLS 가 적용되지 않는다.
  -- 클라이언트가 보낸 공동체 ID 를 그대로 믿으면 남의 공동체 대장에
  -- 글을 쓰고 번호를 축낼 수 있다. 그래서 호출자의 소속으로 정한다.
  -- (공동체를 옮겨 다니는 총관리자만 지정한 값을 인정한다)
  if public.is_super_admin() then
    cid := coalesce(nullif(p->>'community_id','')::uuid, public.my_community_id());
  else
    cid := public.my_community_id();
  end if;
  if cid is null then
    raise exception '소속 공동체를 찾을 수 없습니다.' using errcode = '22004';
  end if;

  -- 동시에 발급해도 번호가 겹치지 않게 (트랜잭션이 끝나면 자동 해제)
  perform pg_advisory_xact_lock(hashtext(cid::text || ':' || yr::text));

  select coalesce(max(seq), 0) + 1 into n
    from public.certificates where community_id = cid and year = yr;

  -- 번호를 직접 적어 넣었으면 그것을 쓴다 (옮겨 적는 경우)
  no := nullif(trim(coalesce(p->>'cert_no', '')), '');
  if no is null then
    no := yr::text || '-' || lpad(n::text, 4, '0');
  end if;

  insert into public.certificates (
    community_id, cert_no, year, seq, lang, type, doc_label, doc_sub,
    student_id, student_name, birth, grade, school,
    statement, reason, issue_date,
    org_id, org_name, org_logo_url, rep, seal_url,
    issued_by, issued_by_name
  ) values (
    cid, no, yr, n,
    coalesce(p->>'lang','ko'), coalesce(p->>'type','enroll'), coalesce(p->>'doc_label',''),
    nullif(p->>'doc_sub',''),
    nullif(p->>'student_id','')::uuid, coalesce(p->>'student_name',''),
    p->>'birth', p->>'grade', p->>'school',
    p->>'statement', p->>'reason', idt,
    nullif(p->>'org_id','')::uuid, p->>'org_name', p->>'org_logo_url',
    p->>'rep', p->>'seal_url',
    auth.uid(), (select name from public.members where id = auth.uid())
  ) returning * into rec;

  return rec;
end
$$;

revoke all on function public.issue_certificate(jsonb) from public, anon;
grant execute on function public.issue_certificate(jsonb) to authenticated;

NOTIFY pgrst, 'reload schema';

-- ── 확인 ──
-- 아래가 1줄 나오면 설치 완료입니다.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'certificates' and column_name = 'doc_sub';
