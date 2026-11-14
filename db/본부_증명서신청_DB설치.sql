-- ═══════════════════════════════════════════════════════════════════
--  📜 본부(IM HQ)에 증명서·수료증 신청하기
--
--  공동체들이 본부에 모여 수련회를 합니다. 전국대회 수료증·활동증명서
--  같은 것은 **본부가 한 줄의 일련번호로** 내줘야 대외에서 통합니다.
--  그래서 「공동체가 신청 → 본부가 승인·발급」 길을 엽니다.
--
--  ★ 새 표를 만들지 않습니다.
--    이미 cert_requests(신청) → certificates(발급 대장) 가 있고,
--    issue_certificate() 가 (공동체, 연도)별로 번호를 매깁니다.
--    여기에 '받는 곳' 한 칸을 더하는 것으로 끝납니다.
--
--  ★ 번호가 지금은 겹칩니다 (재 보았습니다)
--      IM HQ   2026-0001 … 2026-0009
--      IM USA  2026-0001 … 2026-0009   ← 같은 번호
--      프로토스 2026-0001 … 2026-0004   ← 또 같은 번호
--    공동체마다 1번부터 다시 셉니다. 종이에 찍힌 「2026-0007」 만으로는
--    본부 것인지 공동체 것인지 알 수 없습니다. 그래서 공동체마다
--    **머리글(cert_prefix)** 을 둘 수 있게 하고, 본부에 'IMHQ' 를 줍니다.
--      → 앞으로 본부가 내는 것은 IMHQ-2026-0001, IMHQ-2026-0002 …
--    이미 쓴 9개는 건드리지 않습니다. 머리글 없는 줄(series='')과
--    머리글 있는 줄은 따로 셉니다.
--
--  두 번 돌려도 터지지 않습니다.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. 공동체 — 본부 표시와 번호 머리글 ─────────────────────────────
alter table public.communities add column if not exists is_hq boolean not null default false;
alter table public.communities add column if not exists cert_prefix text;

comment on column public.communities.is_hq is
  '본부. 다른 공동체가 증명서를 신청해 오는 곳. 한 곳만 될 수 있다.';
comment on column public.communities.cert_prefix is
  '증명서 번호 머리글. 비우면 2026-0001, ''IMHQ'' 면 IMHQ-2026-0001.';

--  본부는 한 곳뿐이어야 합니다. 두 곳이 되면 신청이 어디로 갈지 모릅니다.
create unique index if not exists communities_one_hq_idx
  on public.communities ((true)) where is_hq;

--  IM HQ 를 본부로 세웁니다. 이름이 바뀌었으면 아무것도 안 합니다
--  (그때는 관리자 화면에서 직접 켜면 됩니다 — 억지로 찍지 않습니다).
update public.communities
   set is_hq = true, cert_prefix = coalesce(cert_prefix, 'IMHQ')
 where name = 'IM HQ' and not is_hq
   and not exists (select 1 from public.communities where is_hq);

-- ── 2. 신청 — '받는 곳' · '한 묶음' · '대회 이름' ────────────────────
alter table public.cert_requests
  add column if not exists to_community_id uuid references public.communities(id) on delete set null;
alter table public.cert_requests add column if not exists batch_id uuid;
alter table public.cert_requests add column if not exists event_name text;

comment on column public.cert_requests.to_community_id is
  '처리할 곳. 비우면 지금처럼 우리 공동체가 처리. 본부 ID 면 본부가 처리한다.';
comment on column public.cert_requests.batch_id is
  '수련회 명단처럼 한 번에 올린 신청을 묶는 끈. 본부가 한꺼번에 승인한다.';
comment on column public.cert_requests.event_name is
  '전국대회 수료증 등에 찍히는 대회·행사 이름.';

create index if not exists cert_requests_to_idx
  on public.cert_requests (to_community_id, status, created_at desc)
  where to_community_id is not null;
create index if not exists cert_requests_batch_idx
  on public.cert_requests (batch_id) where batch_id is not null;

-- ── 3. 발급 대장 — 소속 공동체 · 번호 줄 · 대회 이름 ────────────────
alter table public.certificates add column if not exists for_community_id uuid;
alter table public.certificates add column if not exists for_community_name text;
alter table public.certificates add column if not exists event_name text;
alter table public.certificates add column if not exists series text not null default '';

comment on column public.certificates.for_community_id is
  '이 증서를 받는 사람의 소속 공동체. 본부가 대신 내준 것이면 신청한 공동체.';
comment on column public.certificates.series is
  '번호 줄. ''''(머리글 없음) 과 ''IMHQ'' 는 따로 1번부터 센다.';

create index if not exists certificates_for_idx
  on public.certificates (for_community_id, issue_date desc)
  where for_community_id is not null;

-- ── 4. 보기·고치기 — 본부가 받은 신청을 볼 수 있게 ──────────────────
--
--  ⚠️ 이름을 새로 지어 따로 만듭니다. 기존 cert_requests_select 를
--     고쳐 쓰면, 나중에 옛 설치 파일을 다시 돌릴 때 통째로 덮어쓰여
--     이 길이 조용히 사라집니다.
--
--  ⚠️ drop policy 를 쓰지 않습니다. Supabase 연결이 'drop' 을 보면
--     확인창을 띄우는데, 자동으로 돌릴 때는 그 창에 답할 사람이 없어
--     설치가 통째로 멈춥니다. 있는지 보고 없을 때만 만듭니다.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_requests' and policyname='cert_requests_select_to') then
    create policy cert_requests_select_to on public.cert_requests
      for select to authenticated
      using (public.is_cert_issuer() and to_community_id = (select public.my_community_id()));
  else
    alter policy cert_requests_select_to on public.cert_requests
      using (public.is_cert_issuer() and to_community_id = (select public.my_community_id()));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='cert_requests' and policyname='cert_requests_update_to') then
    create policy cert_requests_update_to on public.cert_requests
      for update to authenticated
      using      (public.is_cert_issuer() and to_community_id = (select public.my_community_id()))
      with check (public.is_cert_issuer() and to_community_id = (select public.my_community_id()));
  else
    alter policy cert_requests_update_to on public.cert_requests
      using      (public.is_cert_issuer() and to_community_id = (select public.my_community_id()))
      with check (public.is_cert_issuer() and to_community_id = (select public.my_community_id()));
  end if;

  --  신청한 공동체가 **결과물**을 볼 수 있게. (고치거나 지우지는 못합니다 —
  --  본부가 낸 증서를 공동체가 무효로 만들면 안 됩니다)
  if not exists (select 1 from pg_policies where schemaname='public'
                  and tablename='certificates' and policyname='certificates_select_for') then
    create policy certificates_select_for on public.certificates
      for select to authenticated
      using (public.is_cert_issuer() and for_community_id = (select public.my_community_id()));
  else
    alter policy certificates_select_for on public.certificates
      using (public.is_cert_issuer() and for_community_id = (select public.my_community_id()));
  end if;
end $$;

-- ── 5. 부총관리자 울타리에 '우리에게 온 것' 을 틔운다 ────────────────
--
--  db/부총관리자_권한_DB설치.sql 이 community_id 가 있는 모든 표에
--  _vice_comm_ins/_upd/_del 선 제한(restrictive) 정책을 깔아 둡니다.
--  선 제한은 AND 로 걸리므로, 본부의 부총관리자(6명)가 다른 공동체에서
--  온 신청을 **승인하지 못합니다.** 그 울타리에 한 줄을 틔웁니다.
--
--  ※ 저 파일의 생성기에도 to_community_id 를 넣어 두었습니다. 그래서
--    저 파일을 다시 돌려도 이 길은 사라지지 않습니다. 여기서 또 하는
--    것은 이 파일만 돌려도 되게 하기 위해서입니다.
--  ※ 여기도 drop 없이 **alter policy** 로 식만 갈아 끼웁니다.
do $$
declare guard text;
begin
  guard := '(not (select public.is_vice_admin()))'
        || ' or community_id is null'
        || ' or community_id = (select public.my_community_id())'
        || ' or to_community_id = (select public.my_community_id())'
        || ' or student_id = (select auth.uid())'
        || ' or requester_id = (select auth.uid())';

  if exists (select 1 from pg_policies where schemaname='public'
              and tablename='cert_requests' and policyname='cert_requests_vice_comm_ins') then
    execute format('alter policy cert_requests_vice_comm_ins on public.cert_requests with check (%s)', guard);
  end if;
  if exists (select 1 from pg_policies where schemaname='public'
              and tablename='cert_requests' and policyname='cert_requests_vice_comm_upd') then
    execute format('alter policy cert_requests_vice_comm_upd on public.cert_requests using (%s) with check (%s)', guard, guard);
  end if;
  if exists (select 1 from pg_policies where schemaname='public'
              and tablename='cert_requests' and policyname='cert_requests_vice_comm_del') then
    execute format('alter policy cert_requests_vice_comm_del on public.cert_requests using (%s)', guard);
  end if;
end $$;

-- ── 6. 공동체가 명단으로 본부에 신청한다 ─────────────────────────────
--
--  표 정책을 넓히지 않고 **좁은 함수 하나**만 엽니다.
--  cert_requests_insert 는 '본인 또는 내 아이' 만 허용합니다. 간사가
--  소속 아이 이름으로 올릴 수 있게 하려면 그 정책을 넓혀야 하는데,
--  그러면 학부모 쪽까지 같이 헐거워집니다. RLS 는 칸 단위로 못 막으니
--  **security definer 함수**가 맞습니다. 여기서 직접 따집니다.
--
--  p = { students:[uuid,…], kind, kind_label, purpose, note, copies, event_name }
create or replace function public.request_certs_to_hq(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me      public.members;
  v_hq      uuid;
  v_batch   uuid := gen_random_uuid();
  v_ids     uuid[];
  v_copies  int  := greatest(1, least(9, coalesce((p->>'copies')::int, 1)));
  v_kind    text := nullif(trim(coalesce(p->>'kind','')), '');
  v_made    int  := 0;
  v_skip    int  := 0;
  r         record;
begin
  select * into v_me from public.members where id = auth.uid();
  if v_me.id is null or coalesce(v_me.status,'active') = 'removed' then
    raise exception '권한이 없습니다.' using errcode = '42501';
  end if;
  --  공동체 관리자·간사만. 학부모·학생은 지금처럼 자기 공동체에 신청합니다.
  if not public.is_staff_of(v_me.community_id) then
    raise exception '공동체 관리자·간사만 본부에 신청할 수 있습니다.' using errcode = '42501';
  end if;
  if v_kind is null then
    raise exception '증명서 종류를 고르세요.' using errcode = '22004';
  end if;

  select id into v_hq from public.communities where is_hq limit 1;
  if v_hq is null then
    raise exception '본부가 정해져 있지 않습니다. 관리자 → 공동체에서 본부를 지정해 주세요.'
      using errcode = '22004';
  end if;
  if v_hq = v_me.community_id then
    raise exception '본부는 증명서 화면에서 바로 발급합니다.' using errcode = '22004';
  end if;

  select array_agg(distinct x)::uuid[] into v_ids
    from jsonb_array_elements_text(coalesce(p->'students','[]'::jsonb)) as t(x);
  if v_ids is null or array_length(v_ids, 1) is null then
    raise exception '신청할 사람을 고르세요.' using errcode = '22004';
  end if;
  if array_length(v_ids, 1) > 300 then
    raise exception '한 번에 300명까지만 됩니다.' using errcode = '22004';
  end if;

  --  ⚠️ 우리 공동체 사람만. 이 함수는 RLS 를 지나지 않으므로, 여기서
  --     막지 않으면 남의 공동체 아이 이름으로 신청이 들어갑니다.
  for r in
    select m.id, m.name from public.members m
     where m.id = any(v_ids)
       and m.community_id = v_me.community_id
       and coalesce(m.status,'active') <> 'removed'
  loop
    insert into public.cert_requests (
      community_id, to_community_id, batch_id, student_id, student_name,
      requester_id, requester_name, relation,
      kind, kind_label, purpose, note, event_name, copies, status
    ) values (
      v_me.community_id, v_hq, v_batch, r.id, r.name,
      v_me.id, v_me.name, 'staff',
      v_kind, nullif(p->>'kind_label',''), nullif(p->>'purpose',''),
      nullif(p->>'note',''), nullif(p->>'event_name',''), v_copies, 'pending'
    );
    v_made := v_made + 1;
  end loop;

  v_skip := array_length(v_ids, 1) - v_made;
  if v_made = 0 then
    raise exception '우리 공동체 사람을 한 명도 찾지 못했습니다.' using errcode = '22004';
  end if;
  return jsonb_build_object('batch_id', v_batch, 'made', v_made, 'skipped', v_skip, 'hq', v_hq);
end $$;

revoke all on function public.request_certs_to_hq(jsonb) from public;
revoke all on function public.request_certs_to_hq(jsonb) from anon;
grant execute on function public.request_certs_to_hq(jsonb) to authenticated;


-- ── 7. 발급 — 번호 줄(머리글)과 소속 공동체를 알게 한다 ───────────────
--
--  바뀐 것은 셋뿐입니다.
--   · 번호 머리글: communities.cert_prefix → IMHQ-2026-0001
--   · 번호를 머리글 줄(series)마다 따로 센다 (옛 9건을 건드리지 않으려고)
--   · 소속 공동체·대회 이름을 함께 적는다
--  나머지는 그대로입니다. create or replace 라 권한도 그대로 남습니다.
create or replace function public.issue_certificate(p jsonb)
returns public.certificates language plpgsql security definer set search_path = public as $$
declare
  cid uuid;
  idt date := coalesce((p->>'issue_date')::date, current_date);
  yr  int  := extract(year from idt)::int;
  ser text;
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

  insert into public.certificates (
    community_id, cert_no, year, seq, series, lang, type, doc_label, doc_sub,
    student_id, student_name, birth, grade, school, address,
    statement, reason, issue_date, event_name,
    for_community_id, for_community_name,
    org_id, org_name, org_logo_url, org_address, rep, seal_url,
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
    auth.uid(), (select name from public.members where id = auth.uid())
  ) returning * into rec;

  return rec;
end $$;
