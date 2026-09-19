-- =====================================================================
--  Triple School 한글 도서목록 (3단계 · 4단계) + 한글책/영어책 구분
--
--  1) reading_books 에 lang 칼럼을 더한다 ('ko' 한글책 / 'en' 영어책)
--     이미 들어있는 책은 전부 영어책('en')으로 본다.
--  2) 3단계 28권 · 4단계 35권 한글책을 넣는다.
--
--  Supabase → SQL Editor 에 통째로 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================

-- ── 1) 언어 칼럼 ──────────────────────────────────────────────────
alter table public.reading_books add column if not exists lang text;
update public.reading_books set lang = 'en' where lang is null;          -- 기존 책 = 영어책
alter table public.reading_books alter column lang set default 'en';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'reading_books_lang_chk') then
    alter table public.reading_books
      add constraint reading_books_lang_chk check (lang in ('ko','en'));
  end if;
end $$;

create index if not exists reading_books_lang_idx on public.reading_books (lang, step, category, sort);

-- ── 2) 한글책 목록 ────────────────────────────────────────────────
--  같은 제목의 영어책이 있어도 lang 이 달라 따로 잡힌다 (읽은 기록도 따로 쌓인다)


-- ── 3단계 (28권) ──
--   Gospel School (9권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','구약여행 14일',0
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='구약여행 14일');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','처음 만나는 구원 이야기',1
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='처음 만나는 구원 이야기');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','만화 성경개관 구약편',2
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='만화 성경개관 구약편');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','만화 성경개관 신약편',3
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='만화 성경개관 신약편');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','하나님나라 이야기',4
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='하나님나라 이야기');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','언약',5
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='언약');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','거듭남이란 무엇인가',6
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='거듭남이란 무엇인가');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','성탄절 메시지',7
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='성탄절 메시지');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Gospel School','부활절 메시지',8
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Gospel School' and title='부활절 메시지');
--   Disciple School (10권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','만화 소교리문답 1',9
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='만화 소교리문답 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','만화 소교리문답 2',10
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='만화 소교리문답 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','예수 생각',11
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='예수 생각');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','네 마음을 지켜라',12
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='네 마음을 지켜라');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','하나님나라 백성이 사는 법',13
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='하나님나라 백성이 사는 법');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','그리스도인의 생활 원리',14
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='그리스도인의 생활 원리');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','예수님이라면 어떻게 하실까',15
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='예수님이라면 어떻게 하실까');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','만화 조나단 에드워즈',16
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='만화 조나단 에드워즈');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','만화 로이드 존스',17
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='만화 로이드 존스');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Disciple School','기도는 예배다',18
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Disciple School' and title='기도는 예배다');
--   Calling School (9권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','마틴 로이드 존스의 가족',19
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='마틴 로이드 존스의 가족');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','당신에게 일은 무엇인가',20
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='당신에게 일은 무엇인가');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','만화 사도행전 1',21
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='만화 사도행전 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','만화 사도행전 2',22
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='만화 사도행전 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','만화 사도행전 3',23
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='만화 사도행전 3');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','존 스토트의 복음 전도',24
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='존 스토트의 복음 전도');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','만화 교회론',25
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='만화 교회론');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','만화 종말론',26
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='만화 종말론');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',3,'Calling School','스크루테이프의 편지',27
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=3 and category='Calling School' and title='스크루테이프의 편지');

-- ── 4단계 (35권) ──
--   Gospel School (6권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','R.C. 스프로울 구원',28
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='R.C. 스프로울 구원');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','복음이 핵심이다',29
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='복음이 핵심이다');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','구약 속 예수',30
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='구약 속 예수');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','복음과 하나님의 나라',31
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='복음과 하나님의 나라');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','언약 (스프로울)',32
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='언약 (스프로울)');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Gospel School','구원의 확신',33
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Gospel School' and title='구원의 확신');
--   Disciple School (11권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','성막으로 보는 그리스도',34
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='성막으로 보는 그리스도');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','기독교 핵심진리 102가지',35
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='기독교 핵심진리 102가지');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','아더 핑크 구원 신앙',36
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='아더 핑크 구원 신앙');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','가상칠언',37
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='가상칠언');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','성령',38
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='성령');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','경건에 이르기를 연습하라',39
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='경건에 이르기를 연습하라');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','복음 안에서 발견된 자유',40
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='복음 안에서 발견된 자유');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','청교도에게 배우는 경건',41
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='청교도에게 배우는 경건');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','좋은 크리스천 잘못된 믿음',42
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='좋은 크리스천 잘못된 믿음');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','해설 천로역정',43
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='해설 천로역정');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Disciple School','순전한 헌신',44
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Disciple School' and title='순전한 헌신');
--   Calling School (18권)
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','삶을 허비하지 마라',45
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='삶을 허비하지 마라');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','가족 구원',46
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='가족 구원');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','부모의 의무',47
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='부모의 의무');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','팀 켈러의 일과 영성',48
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='팀 켈러의 일과 영성');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','기독교 교육 무엇이 다른가',49
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='기독교 교육 무엇이 다른가');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','존 파이퍼 돈, 섹스, 권력',50
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='존 파이퍼 돈, 섹스, 권력');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','선교란 무엇인가',51
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='선교란 무엇인가');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','퍼스펙티브 1',52
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='퍼스펙티브 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','퍼스펙티브 2',53
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='퍼스펙티브 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','선교사 열전',54
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='선교사 열전');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 초대교회사 1',55
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 초대교회사 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 초대교회사 2',56
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 초대교회사 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 중세교회사 1',57
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 중세교회사 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 중세교회사 2',58
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 중세교회사 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','교회와 그리스도의 남은 고난',59
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='교회와 그리스도의 남은 고난');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 요한계시록 1',60
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 요한계시록 1');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','만화 요한계시록 2',61
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='만화 요한계시록 2');
insert into public.reading_books (lang, step, category, title, sort)
select 'ko',4,'Calling School','기독교 세계관과 현대 사상',62
where not exists (select 1 from public.reading_books
                  where lang='ko' and step=4 and category='Calling School' and title='기독교 세계관과 현대 사상');

-- ── 확인 ─────────────────────────────────────────────────────────
select lang, step, category, count(*) as 권수
from public.reading_books
group by lang, step, category
order by lang desc, step, category;

