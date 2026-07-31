-- =====================================================================
--  TCS 전자결재(서류 결재) — 상신 → 결재선 승인 → 최종 완료 → 공유
--  Supabase → SQL Editor 에 붙여넣고 한 번만 실행하세요.
-- =====================================================================

-- ── 권한 헬퍼: 해당 공동체의 교사·간사·관리자인가 ─────────────────────
create or replace function public.appr_is_staff(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members me
    where me.id = auth.uid()
      and (
        me.community_role = 'super_admin'
        or (me.community_id = cid and me.community_role in ('community_admin','admin_officer','teacher','staff'))
      )
  );
$$;

-- ── 1) 결재 양식(템플릿) ────────────────────────────────────────────
create table if not exists public.approval_templates (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name         text not null,
  category     text,
  description  text,
  kind         text not null default 'form',   -- 'form'(칸 채우는 양식) | 'file'(업로드형)
  file_url     text,                            -- kind=file: 양식 파일 URL
  fields       jsonb default '[]'::jsonb,       -- kind=form: 필드 정의
  items        jsonb,                           -- 품목 표 설정(선택)
  sort         int default 0,
  created_by   uuid,
  created_name text,
  created_at   timestamptz default now()
);
create index if not exists idx_appr_tpl_comm on public.approval_templates(community_id, sort);

alter table public.approval_templates enable row level security;
drop policy if exists appr_tpl_select on public.approval_templates;
drop policy if exists appr_tpl_write  on public.approval_templates;
create policy appr_tpl_select on public.approval_templates for select to authenticated
  using (
    exists (select 1 from public.members me where me.id = auth.uid()
            and (me.community_role='super_admin' or me.community_id = approval_templates.community_id))
  );
create policy appr_tpl_write on public.approval_templates for all to authenticated
  using (public.appr_is_staff(community_id)) with check (public.appr_is_staff(community_id));

-- ── 2) 결재 문서 ────────────────────────────────────────────────────
--  line/shares/history 는 JSONB로 내장, participant_ids 로 접근제어
create table if not exists public.approval_docs (
  id             uuid primary key default gen_random_uuid(),
  community_id   uuid not null references public.communities(id) on delete cascade,
  template_id    uuid,
  template_name  text,
  title          text not null,
  form_data      jsonb default '{}'::jsonb,   -- 채운 값
  attachments    jsonb default '[]'::jsonb,   -- [{name,url,size}]
  line           jsonb default '[]'::jsonb,   -- [{order,approver_id,approver_name,status,comment,acted_at}]
  shares         jsonb default '[]'::jsonb,   -- [{member_id,member_name}]
  history        jsonb default '[]'::jsonb,   -- [{ts,actor_id,actor_name,action,comment}]
  participant_ids uuid[] default '{}',        -- 상신자 + 결재자 + 공유자 (접근제어)
  status         text default 'pending',      -- 'pending' | 'approved' | 'rejected' | 'canceled'
  current_step   int default 0,               -- 현재 결재 차례(line 인덱스)
  submitter_id   uuid,
  submitter_name text,
  created_at     timestamptz default now(),
  completed_at   timestamptz
);
create index if not exists idx_appr_doc_comm   on public.approval_docs(community_id, created_at desc);
create index if not exists idx_appr_doc_parts   on public.approval_docs using gin (participant_ids);
create index if not exists idx_appr_doc_submit  on public.approval_docs(submitter_id, created_at desc);

alter table public.approval_docs enable row level security;
drop policy if exists appr_doc_select on public.approval_docs;
drop policy if exists appr_doc_insert on public.approval_docs;
drop policy if exists appr_doc_update on public.approval_docs;
drop policy if exists appr_doc_delete on public.approval_docs;

-- 조회: 참여자(상신/결재/공유) 또는 총관리자·공동체 관리자
create policy appr_doc_select on public.approval_docs for select to authenticated
using (
  auth.uid() = any(participant_ids)
  or exists (select 1 from public.members me where me.id = auth.uid()
             and (me.community_role='super_admin'
                  or (me.community_id = approval_docs.community_id and me.community_role in ('community_admin','admin_officer'))))
);
-- 상신: 본인이 상신자 + 교직원
create policy appr_doc_insert on public.approval_docs for insert to authenticated
with check (submitter_id = auth.uid() and public.appr_is_staff(community_id));
-- 수정(승인/반려/회수): 참여자만 (앱 로직이 실제 동작 제한)
create policy appr_doc_update on public.approval_docs for update to authenticated
using (auth.uid() = any(participant_ids));
-- 삭제: 상신자 본인 또는 관리자
create policy appr_doc_delete on public.approval_docs for delete to authenticated
using (
  submitter_id = auth.uid()
  or exists (select 1 from public.members me where me.id = auth.uid()
             and (me.community_role='super_admin'
                  or (me.community_id = approval_docs.community_id and me.community_role in ('community_admin','admin_officer'))))
);

NOTIFY pgrst, 'reload schema';
