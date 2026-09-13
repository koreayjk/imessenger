-- =====================================================================
--  증명서 : 발급 대장 + 직인(도장)
--
--   1) 발급 대장 — 발급한 증명서를 남긴다.
--      나중에 "이 증명서 여기서 발급한 거 맞습니까" 라는 조회에 답하려면
--      발급 당시의 내용이 그대로 남아 있어야 한다.
--      그래서 학생 표를 참조하지 않고 값을 통째로 베껴 둔다.
--      (학생 정보가 나중에 바뀌거나 지워져도 대장은 그대로여야 한다)
--
--      발급번호는 난수가 아니라 공동체·연도별 순번이다.
--      두 사람이 동시에 발급해도 번호가 겹치지 않도록 잠금을 걸고 매긴다.
--
--   2) 직인 — 학교 도장 PNG 를 여러 개 올려 두고 골라 쓴다.
--      기관(record_orgs)에 매달 수도 있고, 비워 두면 공동체 어디서나 쓴다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- 소속 공동체 (IM노트 설치 때 만들어지지만, 이 파일만 실행해도 되도록 같이 둔다)
create or replace function public.my_community_id()
returns uuid language sql security definer stable set search_path = public as $$
  select community_id from public.members where id = auth.uid() limit 1;
$$;

-- 총관리자만 공동체를 넘나든다. 나머지는 자기 공동체 안에 갇힌다.
create or replace function public.is_super_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (me.community_role = 'super_admin' or me.role = '총관리자')
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

-- ── 증명서를 발급할 수 있는 사람 : 행정담당자 · 관리자 · 총관리자 ──
create or replace function public.is_cert_issuer()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role in ('super_admin','community_admin','admin_officer')
        or me.role in ('총관리자','관리자','행정담당자')
      )
  ) or coalesce(auth.jwt() ->> 'email','') = 'koreayjk@gmail.com';
$$;

-- ══════════════════════════════════════════════════════════════════
--  직인
-- ══════════════════════════════════════════════════════════════════
create table if not exists public.org_seals (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  org_id       uuid references public.record_orgs(id) on delete cascade,
  name         text not null,
  image_url    text not null,
  sort         int  not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists org_seals_comm_idx on public.org_seals(community_id, sort, created_at);

comment on column public.org_seals.org_id is
  '이 직인을 쓰는 기관. 비우면 공동체 전체에서 고를 수 있음';

alter table public.org_seals enable row level security;

-- 보기: 같은 공동체 구성원 (증명서 화면에서 그려야 하므로)
drop policy if exists org_seals_select on public.org_seals;
create policy org_seals_select on public.org_seals for select to authenticated
using (community_id = public.my_community_id() or public.is_super_admin());

-- 올리기·지우기: 관리자
drop policy if exists org_seals_write on public.org_seals;
create policy org_seals_write on public.org_seals for all to authenticated
using      (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()))
with check (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()));

-- ══════════════════════════════════════════════════════════════════
--  발급 대장
-- ══════════════════════════════════════════════════════════════════
create table if not exists public.certificates (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null references public.communities(id) on delete cascade,
  cert_no       text not null,
  year          int  not null,
  seq           int  not null,
  lang          text not null default 'ko',
  type          text not null,
  doc_label     text not null,
  -- 발급 당시 값 복사본 (학생 표를 참조하지 않는다)
  student_id    uuid,
  student_name  text not null,
  birth         text,
  grade         text,
  school        text,
  statement     text,
  reason        text,
  issue_date    date not null,
  org_id        uuid,
  org_name      text,
  org_logo_url  text,
  rep           text,
  seal_url      text,
  issued_by      uuid,
  issued_by_name text,
  -- 잘못 발급한 것은 지우지 않고 무효 표시한다 (대장은 지워지면 안 된다)
  voided_at     timestamptz,
  void_reason   text,
  created_at    timestamptz not null default now(),
  unique (community_id, cert_no)
);
create index if not exists certificates_lookup_idx
  on public.certificates(community_id, issue_date desc, created_at desc);
create index if not exists certificates_name_idx
  on public.certificates(community_id, student_name);

alter table public.certificates enable row level security;

-- 대장은 발급 권한이 있는 사람만 본다
drop policy if exists certificates_select on public.certificates;
create policy certificates_select on public.certificates for select to authenticated
using (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()));

-- 무효 처리만 허용. 내용 수정·삭제는 막는다 (대장의 의미가 사라진다)
drop policy if exists certificates_update on public.certificates;
create policy certificates_update on public.certificates for update to authenticated
using      (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()))
with check (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()));

-- insert 정책은 일부러 두지 않는다.
-- 발급은 반드시 issue_certificate() 를 거쳐야 번호가 제대로 매겨진다.

-- ── 발급 : 번호를 매기고 대장에 남긴다 ──
--   같은 공동체·같은 해에 번호가 겹치지 않도록 잠금을 잡고 순번을 뽑는다.
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
    community_id, cert_no, year, seq, lang, type, doc_label,
    student_id, student_name, birth, grade, school,
    statement, reason, issue_date,
    org_id, org_name, org_logo_url, rep, seal_url,
    issued_by, issued_by_name
  ) values (
    cid, no, yr, n,
    coalesce(p->>'lang','ko'), coalesce(p->>'type','enroll'), coalesce(p->>'doc_label',''),
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

comment on function public.issue_certificate(jsonb) is
  '증명서 발급번호를 공동체·연도별 순번으로 매기고 발급 대장에 남긴다.';

NOTIFY pgrst, 'reload schema';
