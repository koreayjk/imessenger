-- =====================================================================
--  IM노트 — 개인 노트(에버노트 스타일)
--   · 기본은 나만 보는 비공개 노트, 원하면 공동체 전체 공개로 전환
--   · 해시태그(#태그), 노트끼리 연결([[제목]]) + 역링크, 노트북(폴더)
--   · 웹 클리퍼(링크 저장), 첨부파일, 이미지 속 글자(OCR) 검색
--   · 학생 / 채팅방 / 날짜 연결 (TCS 연동)
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행 안전)
-- =====================================================================

-- ─────────────────────────────────────────────────────────────
-- 내 공동체 id (RLS 에서 '공동체 전체 공개' 노트를 가려내는 데 사용)
-- ─────────────────────────────────────────────────────────────
create or replace function public.my_community_id()
returns uuid language sql security definer stable set search_path = public as $$
  select community_id from public.members where id = auth.uid() limit 1;
$$;

-- ─────────────────────────────────────────────────────────────
-- 노트
-- ─────────────────────────────────────────────────────────────
create table if not exists public.notes (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  user_id       uuid not null,                  -- 소유자
  author_name   text,                           -- 표시용(공개 노트에서 작성자 이름)

  title         text not null default '',
  body          text not null default '',
  tags          text[] not null default '{}',   -- 본문의 #태그 를 저장
  notebook      text,                           -- 노트북(폴더). 비우면 '기본'
  pinned        boolean not null default false,
  visibility    text not null default 'private',-- 'private'(나만) | 'community'(공동체 전체)

  -- 웹 클리퍼
  source_url    text,
  source_title  text,
  source_site   text,
  source_image  text,

  -- 첨부 [{url,name,type,size}] · 이미지에서 뽑은 글자(검색용)
  attachments   jsonb not null default '[]'::jsonb,
  ocr_text      text,

  -- TCS 연동
  student_id    uuid,      -- 학생 기록부와 연결
  channel_id    uuid,      -- 채팅방에서 저장한 노트
  event_date    date,      -- 일정과 연결

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists notes_owner_idx     on public.notes(user_id, updated_at desc);
create index if not exists notes_comm_idx      on public.notes(community_id, visibility);
create index if not exists notes_tags_idx      on public.notes using gin(tags);
create index if not exists notes_student_idx   on public.notes(student_id) where student_id is not null;
create index if not exists notes_channel_idx   on public.notes(channel_id) where channel_id is not null;

-- 수정 시각 자동 갱신
create or replace function public.notes_touch()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists notes_touch_trg on public.notes;
create trigger notes_touch_trg before update on public.notes
  for each row execute function public.notes_touch();

alter table public.notes enable row level security;

-- 조회: 내 노트 + 같은 공동체의 '전체 공개' 노트
drop policy if exists notes_select on public.notes;
create policy notes_select on public.notes
  for select to authenticated
  using (
    user_id = auth.uid()
    or (visibility = 'community' and community_id = public.my_community_id())
  );

-- 작성/수정/삭제: 본인 노트만 (총관리자도 남의 개인 노트는 못 봅니다)
drop policy if exists notes_insert on public.notes;
create policy notes_insert on public.notes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists notes_update on public.notes;
create policy notes_update on public.notes
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists notes_delete on public.notes;
create policy notes_delete on public.notes
  for delete to authenticated using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────
-- 노트 템플릿 (회의록 · 심방일지 · 수업계획 …)
--  user_id 가 비어있으면 공동체 공용 템플릿
-- ─────────────────────────────────────────────────────────────
create table if not exists public.note_templates (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  user_id       uuid,
  name          text not null,
  icon          text,
  body          text not null default '',
  tags          text[] not null default '{}',
  created_at    timestamptz not null default now()
);
create index if not exists note_tpl_comm_idx on public.note_templates(community_id);

alter table public.note_templates enable row level security;

drop policy if exists note_tpl_select on public.note_templates;
create policy note_tpl_select on public.note_templates
  for select to authenticated
  using (community_id = public.my_community_id() and (user_id is null or user_id = auth.uid()));

drop policy if exists note_tpl_insert on public.note_templates;
create policy note_tpl_insert on public.note_templates
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists note_tpl_update on public.note_templates;
create policy note_tpl_update on public.note_templates
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists note_tpl_delete on public.note_templates;
create policy note_tpl_delete on public.note_templates
  for delete to authenticated using (user_id = auth.uid());

NOTIFY pgrst, 'reload schema';
