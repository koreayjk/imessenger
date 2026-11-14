-- ═══════════════════════════════════════════════════════════════════
--  🖼 공동체마다 자기 증명서 양식 쓰기
--
--  "증명서 양식을 동일하게 안 가고 각 공동체에서 만든 양식을 사용하게
--   할건데, 기존 양식을 pdf로 한번 올리면 그대로 내용과 이름 이런것들만
--   바꿔서 사용할수 있게. 각 공동체마다 다르게, 없으면 기존거 쓰고"
--
--  ⚠️ 먼저 분명히 해 둘 것 — PDF 를 올려도 그 안의 글자는 못 바꿉니다.
--     · 스캔해서 만든 PDF 는 글자가 아니라 그림입니다
--     · 글자가 있는 PDF 라도 바꾸려면 PDF 를 다시 써야 하고, 한글 글꼴을
--       PDF 안에 심어야 하고, 글자 길이가 달라지면 줄이 어긋납니다
--
--  그래서 **양식을 배경으로 깔고 글자를 그 위에 얹습니다.**
--     ① 양식 PDF(또는 사진)를 올려 첫 장을 그림으로 바꿔 둔다 (bg_url)
--     ② 그 그림 위에서 「이름은 여기」 「본문은 여기」 를 한 번만 정한다 (fields)
--     ③ 발급할 때 배경 + 그 자리에 값을 얹어 인쇄한다
--   스캔이든 글자 PDF든 둘 다 됩니다. 자리는 양식마다 한 번만 정합니다.
--
--  양식이 없는 공동체는 지금 쓰는 기본 증서가 그대로 나갑니다.
--  발급 번호·발급 대장은 **손대지 않습니다** — 양식이 무엇이든 번호는
--  서버가 매기고 대장에 남습니다.
--
--  두 번 돌려도 터지지 않습니다. drop 을 한 글자도 쓰지 않습니다
--  (Supabase 연결이 'drop' 을 보면 확인창을 띄워 설치가 멈춥니다).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.cert_forms (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null references public.communities(id) on delete cascade,
  name          text not null,
  --  어느 증명서에 쓸 양식인가. 비우면 **모든 종류 공용** 이다.
  --  종류별 양식이 있으면 그것을 먼저 쓰고, 없으면 공용을 쓴다.
  kind          text,
  --  배경 그림. PDF 를 올렸으면 첫 장을 그림으로 바꾼 것.
  bg_url        text not null,
  bg_w          int,
  bg_h          int,
  landscape     boolean not null default false,
  --  글자 자리. [{ k:'name', x:0.5, y:0.33, w:0.4, align:'center', size:18, bold:true }]
  --   x·y·w 는 **그림 크기에 대한 비율(0~1)** 이다. 픽셀로 적으면 화면
  --   크기가 바뀔 때마다 자리가 어긋난다.
  fields        jsonb not null default '[]'::jsonb,
  enabled       boolean not null default true,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.cert_forms is
  '공동체가 올린 증명서 양식. 배경 그림 + 글자 자리. 없으면 기본 증서를 쓴다.';
comment on column public.cert_forms.kind is
  '이 양식을 쓸 증명서 종류(CERT_TYPES 열쇠). 비우면 모든 종류 공용.';
comment on column public.cert_forms.fields is
  '글자 자리. x·y·w 는 그림에 대한 비율(0~1) — 픽셀로 적으면 화면이 바뀔 때 어긋난다.';

--  한 공동체의 한 종류에 양식은 하나. 둘이면 어느 것이 나갈지 모릅니다.
--  (kind 가 비어 있는 '공용' 도 하나만)
create unique index if not exists cert_forms_one_per_kind_idx
  on public.cert_forms (community_id, coalesce(kind, '*'));

create index if not exists cert_forms_comm_idx
  on public.cert_forms (community_id) where enabled;

alter table public.cert_forms enable row level security;

-- ── 보기·쓰기 ───────────────────────────────────────────────────────
--  보기 : 우리 공동체 것 (mine_comm 이 총관리자·부총관리자 범위까지 안다)
--  쓰기 : 증명서를 발급할 수 있는 사람 + 자기 공동체만
--         (certificates_update 와 같은 선입니다)
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_forms' and policyname='cert_forms_select') then
    create policy cert_forms_select on public.cert_forms
      for select to authenticated using (public.mine_comm(community_id));
  else
    alter policy cert_forms_select on public.cert_forms
      using (public.mine_comm(community_id));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_forms' and policyname='cert_forms_ins') then
    create policy cert_forms_ins on public.cert_forms
      for insert to authenticated
      with check (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  else
    alter policy cert_forms_ins on public.cert_forms
      with check (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_forms' and policyname='cert_forms_upd') then
    create policy cert_forms_upd on public.cert_forms
      for update to authenticated
      using      (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()))
      with check (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  else
    alter policy cert_forms_upd on public.cert_forms
      using      (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()))
      with check (public.is_cert_issuer()
                  and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_forms' and policyname='cert_forms_del') then
    create policy cert_forms_del on public.cert_forms
      for delete to authenticated
      using (public.is_cert_issuer()
             and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  else
    alter policy cert_forms_del on public.cert_forms
      using (public.is_cert_issuer()
             and (community_id = (select public.my_community_id()) or public.is_super_admin()));
  end if;
end $$;

-- ── 고친 때를 적어 둔다 ─────────────────────────────────────────────
create or replace function public.cert_forms_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_trigger
                  where tgname = 'cert_forms_touch_trg'
                    and tgrelid = 'public.cert_forms'::regclass) then
    create trigger cert_forms_touch_trg before update on public.cert_forms
      for each row execute function public.cert_forms_touch();
  end if;
end $$;

-- ── 발급한 증서에 '어떤 양식으로 냈는지' 를 남긴다 ──────────────────
--  왜 — 양식을 나중에 고치거나 지우면, 옛 증서를 다시 뽑을 때 다른
--  모양으로 나옵니다. 그때 쓴 양식과 자리를 증서에 함께 떠 둡니다.
alter table public.certificates add column if not exists form_id   uuid;
alter table public.certificates add column if not exists form_snap jsonb;
comment on column public.certificates.form_snap is
  '발급할 때 쓴 양식(배경 주소와 글자 자리)을 그대로 떠 둔 것. 양식이 바뀌어도 그때 문서를 다시 뽑을 수 있다.';


-- ── 발급 함수 — 어떤 양식으로 냈는지 함께 적는다 ────────────────────
--  ⚠️ 클라이언트가 보낸 **양식 내용은 믿지 않습니다.** form_id 만 받아서
--     발급하는 공동체의 양식 표에서 직접 읽어 떠 둡니다. 안 그러면
--     남의 양식이나 아무 그림을 증서에 박아 넣을 수 있습니다.
--
--  (아래는 db/본부_증명서신청_DB설치.sql 의 함수에 form_id·form_snap
--   두 줄이 더해진 것입니다. 늦게 돌리는 쪽이 이깁니다 — 이 파일을
--   나중에 돌리세요.)
create or replace function public.issue_certificate(p jsonb)
returns public.certificates language plpgsql security definer set search_path = public as $$
declare
  cid uuid;
  idt date := coalesce((p->>'issue_date')::date, current_date);
  yr  int  := extract(year from idt)::int;
  ser text;
  n   int;
  no  text;
  fid uuid := nullif(p->>'form_id','')::uuid;
  snap jsonb;
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

  --  번호 머리글은 **발급하는 공동체**의 것을 쓴다. 클라이언트가 보낸
  --  값은 쓰지 않는다 — 그러면 아무나 IMHQ 번호를 찍을 수 있다.
  select coalesce(cert_prefix, '') into ser from public.communities where id = cid;
  ser := coalesce(ser, '');

  -- 동시에 발급해도 번호가 겹치지 않게 (트랜잭션이 끝나면 자동 해제)
  perform pg_advisory_xact_lock(hashtext(cid::text || ':' || yr::text || ':' || ser));

  select coalesce(max(seq), 0) + 1 into n
    from public.certificates
   where community_id = cid and year = yr and coalesce(series,'') = ser;

  -- 번호를 직접 적어 넣었으면 그것을 쓴다 (옮겨 적는 경우)
  no := nullif(trim(coalesce(p->>'cert_no', '')), '');
  if no is null then
    no := case when ser = '' then '' else ser || '-' end
       || yr::text || '-' || lpad(n::text, 4, '0');
  end if;

  --  어떤 양식으로 냈는지 떠 둔다 (form_id 만 받아 양식 표에서 직접 읽는다)
  if fid is not null then
    select jsonb_build_object(
             'id', f.id, 'name', f.name, 'kind', f.kind, 'bg_url', f.bg_url,
             'bg_w', f.bg_w, 'bg_h', f.bg_h, 'landscape', f.landscape, 'fields', f.fields)
      into snap
      from public.cert_forms f
     where f.id = fid and f.community_id = cid;
    if snap is null then fid := null; end if;
  end if;

  insert into public.certificates (
    community_id, cert_no, year, seq, series, lang, type, doc_label, doc_sub,
    student_id, student_name, birth, grade, school, address,
    statement, reason, issue_date, event_name,
    for_community_id, for_community_name,
    org_id, org_name, org_logo_url, org_address, rep, seal_url,
    form_id, form_snap,
    issued_by, issued_by_name
  ) values (
    cid, no, yr, n, ser,
    coalesce(p->>'lang','ko'), coalesce(p->>'type','custom'), coalesce(p->>'doc_label',''),
    nullif(p->>'doc_sub',''),
    nullif(p->>'student_id','')::uuid, coalesce(p->>'student_name',''),
    p->>'birth', p->>'grade', p->>'school', p->>'address',
    p->>'statement', p->>'reason', idt, nullif(p->>'event_name',''),
    --  소속 공동체는 적어 온 것을 쓰되, 안 적으면 발급한 공동체로 둔다.
    --  거짓으로 적어도 번호는 cid 줄에서 나가므로 대장이 어긋나지 않는다.
    coalesce(nullif(p->>'for_community_id','')::uuid, cid),
    coalesce(nullif(p->>'for_community_name',''),
             (select name from public.communities
               where id = coalesce(nullif(p->>'for_community_id','')::uuid, cid))),
    nullif(p->>'org_id','')::uuid, p->>'org_name', p->>'org_logo_url', p->>'org_address',
    p->>'rep', p->>'seal_url',
    fid, snap,
    auth.uid(), (select name from public.members where id = auth.uid())
  ) returning * into rec;

  return rec;
end $$;
