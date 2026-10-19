-- ════════════════════════════════════════════════════════════════════
--  🌐 화면 언어를 사람마다 따로
--
--  "언어 선택을 관리자가 전체로 적용해서 가는 게 아니라 개개인 별로
--   한글 영어 이렇게 바꿔서 보여지게 할 수 있지?"
--
--  됩니다. 지금은 communities.language 한 줄이라, 관리자가 영어로
--  바꾸면 그 공동체 사람 전부가 영어로 보였습니다. 한국어가 편한
--  분과 영어가 편한 분이 같은 방에 있는데 한쪽만 맞출 수 있었습니다.
--
--  members 에 자기 언어를 둡니다. 적어 두지 않은 사람은 예전처럼
--  공동체 언어를 따릅니다 — 지금 쓰는 분들의 화면이 갑자기
--  바뀌지 않습니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

alter table public.members
  add column if not exists language text;

-- 'ko' 와 'en' 만 받는다. 엉뚱한 값이 들어가면 화면이 한국어로 떨어진다.
do $$
begin
  alter table public.members
    add constraint members_language_chk check (language in ('ko','en'));
exception
  when duplicate_object then null;
  when others then null;
end $$;

notify pgrst, 'reload schema';

select '설치 끝 — 이제 사람마다 언어를 따로 고를 수 있어요' as "결과";
