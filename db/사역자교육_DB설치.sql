-- =====================================================================
--  🎓 사역자 교육 (운영관리 → 사역자 교육)
--   · trainings       교육 자료 (영상 / 도서 / 아티클) + 작성자가 붙인 질문
--   · training_notes  느낀점 · 북리뷰 + 별점 + 질문 답변 + 이모지 반응
--   · training_done   완료(완독) 체크
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================

create table if not exists public.trainings (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null,
  kind            text not null default 'video',    -- video | book | article
  category        text not null default 'common',    -- bible/ministry/teach/counsel/leader/admin/common
  title           text not null,
  author          text,                              -- 저자 (도서)
  url             text,                              -- 영상: 유튜브 / 아티클: URL / 도서: 소개·구매(선택)
  cover_url       text,                              -- 책 표지 이미지
  description     text,                              -- 설명 · 추천 이유
  lead_msg        text,                              -- 담당자 한마디
  questions       jsonb   not null default '[]'::jsonb,  -- 작성자가 붙인 질문 [{id,text}]
  required        boolean not null default false,    -- 필수 여부
  due_date        date,                              -- 필수 마감일 (선택)
  sort            int     default 0,
  created_by      uuid,
  created_by_name text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- 느낀점 · 북리뷰.
-- 한 행에 한 사람의 후기. (jsonb 배열 한 칸에 몰아넣으면 여러 명이 동시에 쓸 때
--  서로의 글을 덮어쓴다. 그래서 따로 테이블로 뺐다.)
create table if not exists public.training_notes (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  training_id   uuid not null references public.trainings(id) on delete cascade,
  member_id     uuid,
  author_name   text,
  text          text,                                -- 자유 느낀점 · 북리뷰 본문
  rating        int,                                 -- 별점 1~5 (0/null = 안 매김)
  answers       jsonb not null default '{}'::jsonb,   -- 질문 답변 {"질문id":"답변"}
  reactions     jsonb not null default '{}'::jsonb,   -- {"👍":["이름",...]}
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create table if not exists public.training_done (
  id            uuid primary key default gen_random_uuid(),
  community_id  uuid not null,
  training_id   uuid not null references public.trainings(id) on delete cascade,
  member_id     uuid not null,
  member_name   text,
  done_at       date not null default current_date,
  created_at    timestamptz default now()
);

create unique index if not exists training_done_uidx      on public.training_done (training_id, member_id);
create index        if not exists trainings_comm_idx      on public.trainings (community_id, created_at desc);
create index        if not exists training_notes_t_idx    on public.training_notes (training_id, created_at desc);
create index        if not exists training_notes_comm_idx on public.training_notes (community_id);
create index        if not exists training_done_comm_idx  on public.training_done (community_id);

-- RLS — 로그인 사용자 접근 허용 (다른 학사·운영 테이블과 같은 방식)
alter table public.trainings      enable row level security;
alter table public.training_notes enable row level security;
alter table public.training_done  enable row level security;

drop policy if exists trainings_rw on public.trainings;
create policy trainings_rw on public.trainings for all to authenticated using (true) with check (true);

drop policy if exists training_notes_rw on public.training_notes;
create policy training_notes_rw on public.training_notes for all to authenticated using (true) with check (true);

drop policy if exists training_done_rw on public.training_done;
create policy training_done_rw on public.training_done for all to authenticated using (true) with check (true);

-- 책 검색(구글 북스)에 쓸 API 키를 공동체 설정에 둔다.
-- 앱 코드(index.html)는 공개 저장소에 있어서 거기에 키를 박으면 봇이 긁어가 할당량을 태운다.
-- 여기 넣으면 git 에는 안 들어간다. (구글 클라우드 콘솔에서 HTTP 리퍼러 제한도 꼭 걸어두세요)
alter table public.communities add column if not exists books_api_key text;

notify pgrst, 'reload schema';

-- =====================================================================
--  끝. 운영관리 → 🎓 사역자 교육 에서 바로 쓸 수 있습니다.
-- =====================================================================
