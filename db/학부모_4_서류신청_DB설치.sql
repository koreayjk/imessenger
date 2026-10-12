-- =====================================================================
--  📄 4단계 — 서류 신청
--
--  요청 (개선창 · Clara · IM HQ)
--   "서류 신청도 이 플랫폼 통해서 할 수 있게요! 예를 들면 재학 증명서,
--    학비 납입 증명서 등을 요청할 수 있으면요!"
--
--  흐름
--    학부모(또는 학생)가 '서류 신청' → 관리자 증명서 화면의 '신청함' 에
--    뜸 → [이 신청으로 발급] 을 누르면 발급 폼이 그 학생·그 종류로 채워
--    진 채 열림 → 발급하면 신청이 '발급 완료' 가 되고 발급번호가 붙음
--
--  증명서 발급 기능 자체는 이미 있습니다. 신청함만 앞에 붙입니다.
--
--  ※ 1단계(칸막이)를 먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

do $$
begin
  if to_regprocedure('public.my_children()') is null then
    raise exception '먼저 db/학부모_1_칸막이_DB설치.sql 을 실행해주세요.';
  end if;
end $$;

create table if not exists public.cert_requests (
  id             uuid primary key default gen_random_uuid(),
  community_id   uuid not null,
  student_id     uuid not null references public.members(id) on delete cascade,
  student_name   text,
  requester_id   uuid,
  requester_name text,
  relation       text,                       -- '모' | '부' | '본인' ...
  kind           text not null,              -- CERT_TYPES 의 열쇠 (enroll | tuition_paid | admit ...)
  kind_label     text,                       -- 신청 당시 이름 (나중에 종류가 바뀌어도 남게)
  purpose        text,                       -- 어디에 내려고
  note           text,
  copies         int not null default 1,
  status         text not null default 'pending',   -- pending | issued | rejected | canceled
  certificate_id uuid,                       -- 발급되면 발급대장의 그 줄
  cert_no        text,
  handled_by     uuid,
  handled_name   text,
  handled_at     timestamptz,
  reject_reason  text,
  created_at     timestamptz not null default now()
);
create index if not exists cert_requests_comm_idx on public.cert_requests (community_id, status, created_at desc);
create index if not exists cert_requests_stu_idx  on public.cert_requests (student_id, created_at desc);

comment on table public.cert_requests is
  '학부모·학생이 올리는 증명서 신청. 발급은 기존 증명서 화면에서 한다.';

alter table public.cert_requests enable row level security;

-- 보기 — 신청한 사람, 그 학생 본인, 그 아이의 부모, 그리고 발급 담당자
drop policy if exists cert_requests_select on public.cert_requests;
create policy cert_requests_select on public.cert_requests for select to authenticated
using (
  requester_id = auth.uid()
  or student_id = auth.uid()
  or student_id in (select public.my_children())
  or (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()))
);

-- 올리기 — 자기 이름으로, 자기 아이(또는 자기 자신) 것만
drop policy if exists cert_requests_insert on public.cert_requests;
create policy cert_requests_insert on public.cert_requests for insert to authenticated
with check (
  requester_id = auth.uid()
  and coalesce(status,'pending') = 'pending'
  and ( student_id = auth.uid() or student_id in (select public.my_children()) )
);

-- 처리 — 발급 담당자만. 신청자는 고치지 못한다(지우고 다시 올린다).
drop policy if exists cert_requests_update on public.cert_requests;
create policy cert_requests_update on public.cert_requests for update to authenticated
using      ( public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()) )
with check ( public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()) );

-- 취소 — 아직 처리 전인 내 신청만. 발급된 것은 지우지 못한다(기록이 남아야 한다).
drop policy if exists cert_requests_delete on public.cert_requests;
create policy cert_requests_delete on public.cert_requests for delete to authenticated
using (
  (requester_id = auth.uid() and status = 'pending')
  or (public.is_cert_issuer() and (community_id = public.my_community_id() or public.is_super_admin()))
);

grant select, insert, update, delete on public.cert_requests to authenticated;

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select policyname as "정책", cmd as "대상"
  from pg_policies where schemaname='public' and tablename='cert_requests' order by 2, 1;

-- =====================================================================
--  학부모 화면 '내 아이' 아래에 📄 서류 신청 이 생기고,
--  운영관리 → 증명서 에 '신청함' 탭이 생깁니다.
-- =====================================================================
