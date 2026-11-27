-- =====================================================================
--  📜 성구암송 내용 ① — 네비게이토 주제별 성구암송 (TMS) 60구절
--
--  다섯 묶음(A~E) × 주제 여섯 × 두 구절 = 60구절.
--  한글과 영어를 따로 담습니다. 같은 구절이라도 줄을 따로 두어,
--  학생이 한글로 외운 것과 영어로 외운 것을 각각 체크합니다.
--
--  ⚠️ 2026-11-27 — 성경 본문을 뺐습니다. 구절 주소만 담습니다.
--
--     전에는 한글(개역개정)과 영어(NIV) 본문을 이 파일에 그대로 적어
--     넣었습니다. 두 번역본 모두 저작권이 있습니다 —
--       · 개역개정 : 대한성서공회
--       · NIV      : Biblica, Inc.
--     공개 저장소에 올라가는 파일이고, 앱에도 그대로 실렸습니다.
--     권리를 받지 않은 채 둘 수는 없어서 본문을 뺐습니다.
--
--     이제 화면에는 「갈라디아서 2:20」 처럼 **구절 주소만** 나옵니다.
--     본문은 각자 성경책이나 쓰시는 성경 앱에서 찾아 읽고 외웁니다.
--     (앱 코드도 같이 고쳤습니다 — 묵상의 본문 자동 입력도 뺐습니다)
--
--     공동체에서 쓰시는 번역본의 권리를 받으셨다면, 학사 → 성구암송 →
--     항목 관리 에서 구절마다 본문을 직접 넣으실 수 있습니다.
--
--  ※ db/성구암송_DB설치.sql 과 db/성구암송_분류언어_DB설치.sql 을
--    먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

delete from public.memory_items where kind = 'verse' and community_id is null;

insert into public.memory_items (kind, lang, no, title, series, topic, community_id, sort) values
  ('verse', 'ko', 1, '고린도후서 5:17', 'A. 새로운 삶', '중심되신 그리스도', null, 1),
  ('verse', 'en', 1, '2 Corinthians 5:17', 'A. The New Life', 'Christ the Center', null, 1),
  ('verse', 'ko', 2, '갈라디아서 2:20', 'A. 새로운 삶', '중심되신 그리스도', null, 2),
  ('verse', 'en', 2, 'Galatians 2:20', 'A. The New Life', 'Christ the Center', null, 2),
  ('verse', 'ko', 3, '로마서 12:1', 'A. 새로운 삶', '그리스도께 순종', null, 3),
  ('verse', 'en', 3, 'Romans 12:1', 'A. The New Life', 'Obedience to Christ', null, 3),
  ('verse', 'ko', 4, '요한복음 14:21', 'A. 새로운 삶', '그리스도께 순종', null, 4),
  ('verse', 'en', 4, 'John 14:21', 'A. The New Life', 'Obedience to Christ', null, 4),
  ('verse', 'ko', 5, '디모데후서 3:16', 'A. 새로운 삶', '말씀', null, 5),
  ('verse', 'en', 5, '2 Timothy 3:16', 'A. The New Life', 'The Word', null, 5),
  ('verse', 'ko', 6, '여호수아 1:8', 'A. 새로운 삶', '말씀', null, 6),
  ('verse', 'en', 6, 'Joshua 1:8', 'A. The New Life', 'The Word', null, 6),
  ('verse', 'ko', 7, '요한복음 15:7', 'A. 새로운 삶', '기도', null, 7),
  ('verse', 'en', 7, 'John 15:7', 'A. The New Life', 'Prayer', null, 7),
  ('verse', 'ko', 8, '빌립보서 4:6-7', 'A. 새로운 삶', '기도', null, 8),
  ('verse', 'en', 8, 'Philippians 4:6-7', 'A. The New Life', 'Prayer', null, 8),
  ('verse', 'ko', 9, '마태복음 18:20', 'A. 새로운 삶', '교제', null, 9),
  ('verse', 'en', 9, 'Matthew 18:20', 'A. The New Life', 'Fellowship', null, 9),
  ('verse', 'ko', 10, '히브리서 10:24-25', 'A. 새로운 삶', '교제', null, 10),
  ('verse', 'en', 10, 'Hebrews 10:24-25', 'A. The New Life', 'Fellowship', null, 10),
  ('verse', 'ko', 11, '마태복음 4:19', 'A. 새로운 삶', '증거', null, 11),
  ('verse', 'en', 11, 'Matthew 4:19', 'A. The New Life', 'Witnessing', null, 11),
  ('verse', 'ko', 12, '로마서 1:16', 'A. 새로운 삶', '증거', null, 12),
  ('verse', 'en', 12, 'Romans 1:16', 'A. The New Life', 'Witnessing', null, 12),
  ('verse', 'ko', 13, '로마서 3:23', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 13),
  ('verse', 'en', 13, 'Romans 3:23', 'B. Proclaim Christ', 'All Have Sinned', null, 13),
  ('verse', 'ko', 14, '이사야 53:6', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 14),
  ('verse', 'en', 14, 'Isaiah 53:6', 'B. Proclaim Christ', 'All Have Sinned', null, 14),
  ('verse', 'ko', 15, '로마서 6:23', 'B. 그리스도를 전파함', '죄의 형벌', null, 15),
  ('verse', 'en', 15, 'Romans 6:23', 'B. Proclaim Christ', 'Sin''s Penalty', null, 15),
  ('verse', 'ko', 16, '히브리서 9:27', 'B. 그리스도를 전파함', '죄의 형벌', null, 16),
  ('verse', 'en', 16, 'Hebrews 9:27', 'B. Proclaim Christ', 'Sin''s Penalty', null, 16),
  ('verse', 'ko', 17, '로마서 5:8', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 17),
  ('verse', 'en', 17, 'Romans 5:8', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 17),
  ('verse', 'ko', 18, '베드로전서 3:18', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 18),
  ('verse', 'en', 18, '1 Peter 3:18', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 18),
  ('verse', 'ko', 19, '에베소서 2:8-9', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 19),
  ('verse', 'en', 19, 'Ephesians 2:8-9', 'B. Proclaim Christ', 'Salvation Not by Works', null, 19),
  ('verse', 'ko', 20, '디도서 3:5', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 20),
  ('verse', 'en', 20, 'Titus 3:5', 'B. Proclaim Christ', 'Salvation Not by Works', null, 20),
  ('verse', 'ko', 21, '요한복음 1:12', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 21),
  ('verse', 'en', 21, 'John 1:12', 'B. Proclaim Christ', 'Must Receive Christ', null, 21),
  ('verse', 'ko', 22, '요한계시록 3:20', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 22),
  ('verse', 'en', 22, 'Revelation 3:20', 'B. Proclaim Christ', 'Must Receive Christ', null, 22),
  ('verse', 'ko', 23, '요한일서 5:13', 'B. 그리스도를 전파함', '구원의 확신', null, 23),
  ('verse', 'en', 23, '1 John 5:13', 'B. Proclaim Christ', 'Assurance of Salvation', null, 23),
  ('verse', 'ko', 24, '요한복음 5:24', 'B. 그리스도를 전파함', '구원의 확신', null, 24),
  ('verse', 'en', 24, 'John 5:24', 'B. Proclaim Christ', 'Assurance of Salvation', null, 24),
  ('verse', 'ko', 25, '고린도전서 3:16', 'C. 하나님을 의뢰함', '성령', null, 25),
  ('verse', 'en', 25, '1 Corinthians 3:16', 'C. Rely on God''s Resources', 'His Spirit', null, 25),
  ('verse', 'ko', 26, '고린도전서 2:12', 'C. 하나님을 의뢰함', '성령', null, 26),
  ('verse', 'en', 26, '1 Corinthians 2:12', 'C. Rely on God''s Resources', 'His Spirit', null, 26),
  ('verse', 'ko', 27, '이사야 41:10', 'C. 하나님을 의뢰함', '능력', null, 27),
  ('verse', 'en', 27, 'Isaiah 41:10', 'C. Rely on God''s Resources', 'His Strength', null, 27),
  ('verse', 'ko', 28, '빌립보서 4:13', 'C. 하나님을 의뢰함', '능력', null, 28),
  ('verse', 'en', 28, 'Philippians 4:13', 'C. Rely on God''s Resources', 'His Strength', null, 28),
  ('verse', 'ko', 29, '예레미야애가 3:22-23', 'C. 하나님을 의뢰함', '성실', null, 29),
  ('verse', 'en', 29, 'Lamentations 3:22-23', 'C. Rely on God''s Resources', 'His Faithfulness', null, 29),
  ('verse', 'ko', 30, '민수기 23:19', 'C. 하나님을 의뢰함', '성실', null, 30),
  ('verse', 'en', 30, 'Numbers 23:19', 'C. Rely on God''s Resources', 'His Faithfulness', null, 30),
  ('verse', 'ko', 31, '이사야 26:3', 'C. 하나님을 의뢰함', '평안', null, 31),
  ('verse', 'en', 31, 'Isaiah 26:3', 'C. Rely on God''s Resources', 'His Peace', null, 31),
  ('verse', 'ko', 32, '베드로전서 5:7', 'C. 하나님을 의뢰함', '평안', null, 32),
  ('verse', 'en', 32, '1 Peter 5:7', 'C. Rely on God''s Resources', 'His Peace', null, 32),
  ('verse', 'ko', 33, '로마서 8:32', 'C. 하나님을 의뢰함', '공급', null, 33),
  ('verse', 'en', 33, 'Romans 8:32', 'C. Rely on God''s Resources', 'His Provision', null, 33),
  ('verse', 'ko', 34, '빌립보서 4:19', 'C. 하나님을 의뢰함', '공급', null, 34),
  ('verse', 'en', 34, 'Philippians 4:19', 'C. Rely on God''s Resources', 'His Provision', null, 34),
  ('verse', 'ko', 35, '히브리서 2:18', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 35),
  ('verse', 'en', 35, 'Hebrews 2:18', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 35),
  ('verse', 'ko', 36, '시편 119:9,11', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 36),
  ('verse', 'en', 36, 'Psalm 119:9,11', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 36),
  ('verse', 'ko', 37, '마태복음 6:33', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 37),
  ('verse', 'en', 37, 'Matthew 6:33', 'D. Be Christ''s Disciple', 'Put Christ First', null, 37),
  ('verse', 'ko', 38, '누가복음 9:23', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 38),
  ('verse', 'en', 38, 'Luke 9:23', 'D. Be Christ''s Disciple', 'Put Christ First', null, 38),
  ('verse', 'ko', 39, '요한일서 2:15-16', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 39),
  ('verse', 'en', 39, '1 John 2:15-16', 'D. Be Christ''s Disciple', 'Separate from the World', null, 39),
  ('verse', 'ko', 40, '로마서 12:2', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 40),
  ('verse', 'en', 40, 'Romans 12:2', 'D. Be Christ''s Disciple', 'Separate from the World', null, 40),
  ('verse', 'ko', 41, '고린도전서 15:58', 'D. 그리스도 제자의 자격', '견고함', null, 41),
  ('verse', 'en', 41, '1 Corinthians 15:58', 'D. Be Christ''s Disciple', 'Steadfast', null, 41),
  ('verse', 'ko', 42, '히브리서 12:3', 'D. 그리스도 제자의 자격', '견고함', null, 42),
  ('verse', 'en', 42, 'Hebrews 12:3', 'D. Be Christ''s Disciple', 'Steadfast', null, 42),
  ('verse', 'ko', 43, '마가복음 10:45', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 43),
  ('verse', 'en', 43, 'Mark 10:45', 'D. Be Christ''s Disciple', 'Serve Others', null, 43),
  ('verse', 'ko', 44, '고린도후서 4:5', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 44),
  ('verse', 'en', 44, '2 Corinthians 4:5', 'D. Be Christ''s Disciple', 'Serve Others', null, 44),
  ('verse', 'ko', 45, '잠언 3:9-10', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 45),
  ('verse', 'en', 45, 'Proverbs 3:9-10', 'D. Be Christ''s Disciple', 'Give Generously', null, 45),
  ('verse', 'ko', 46, '고린도후서 9:6-7', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 46),
  ('verse', 'en', 46, '2 Corinthians 9:6-7', 'D. Be Christ''s Disciple', 'Give Generously', null, 46),
  ('verse', 'ko', 47, '사도행전 1:8', 'D. 그리스도 제자의 자격', '세계 비전', null, 47),
  ('verse', 'en', 47, 'Acts 1:8', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 47),
  ('verse', 'ko', 48, '마태복음 28:19-20', 'D. 그리스도 제자의 자격', '세계 비전', null, 48),
  ('verse', 'en', 48, 'Matthew 28:19-20', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 48),
  ('verse', 'ko', 49, '요한복음 13:34-35', 'E. 그리스도를 닮아감', '사랑', null, 49),
  ('verse', 'en', 49, 'John 13:34-35', 'E. Grow in Christlikeness', 'Love', null, 49),
  ('verse', 'ko', 50, '요한일서 3:18', 'E. 그리스도를 닮아감', '사랑', null, 50),
  ('verse', 'en', 50, '1 John 3:18', 'E. Grow in Christlikeness', 'Love', null, 50),
  ('verse', 'ko', 51, '빌립보서 2:3-4', 'E. 그리스도를 닮아감', '겸손', null, 51),
  ('verse', 'en', 51, 'Philippians 2:3-4', 'E. Grow in Christlikeness', 'Humility', null, 51),
  ('verse', 'ko', 52, '베드로전서 5:5-6', 'E. 그리스도를 닮아감', '겸손', null, 52),
  ('verse', 'en', 52, '1 Peter 5:5-6', 'E. Grow in Christlikeness', 'Humility', null, 52),
  ('verse', 'ko', 53, '에베소서 5:3', 'E. 그리스도를 닮아감', '순결', null, 53),
  ('verse', 'en', 53, 'Ephesians 5:3', 'E. Grow in Christlikeness', 'Purity', null, 53),
  ('verse', 'ko', 54, '베드로전서 2:11', 'E. 그리스도를 닮아감', '순결', null, 54),
  ('verse', 'en', 54, '1 Peter 2:11', 'E. Grow in Christlikeness', 'Purity', null, 54),
  ('verse', 'ko', 55, '레위기 19:11', 'E. 그리스도를 닮아감', '정직', null, 55),
  ('verse', 'en', 55, 'Leviticus 19:11', 'E. Grow in Christlikeness', 'Honesty', null, 55),
  ('verse', 'ko', 56, '사도행전 24:16', 'E. 그리스도를 닮아감', '정직', null, 56),
  ('verse', 'en', 56, 'Acts 24:16', 'E. Grow in Christlikeness', 'Honesty', null, 56),
  ('verse', 'ko', 57, '히브리서 11:6', 'E. 그리스도를 닮아감', '믿음', null, 57),
  ('verse', 'en', 57, 'Hebrews 11:6', 'E. Grow in Christlikeness', 'Faith', null, 57),
  ('verse', 'ko', 58, '로마서 4:20-21', 'E. 그리스도를 닮아감', '믿음', null, 58),
  ('verse', 'en', 58, 'Romans 4:20-21', 'E. Grow in Christlikeness', 'Faith', null, 58),
  ('verse', 'ko', 59, '갈라디아서 6:9-10', 'E. 그리스도를 닮아감', '선행', null, 59),
  ('verse', 'en', 59, 'Galatians 6:9-10', 'E. Grow in Christlikeness', 'Good Works', null, 59),
  ('verse', 'ko', 60, '마태복음 5:16', 'E. 그리스도를 닮아감', '선행', null, 60),
  ('verse', 'en', 60, 'Matthew 5:16', 'E. Grow in Christlikeness', 'Good Works', null, 60);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select lang as "말", count(*) as "구절", count(distinct series) as "묶음", count(distinct topic) as "주제"
  from public.memory_items where kind='verse' group by 1 order by 1;

--  본문이 한 줄도 안 들어갔는지 (0 이어야 합니다)
select count(*) as "본문이 들어간 줄"
  from public.memory_items where kind='verse' and coalesce(body,'') <> '';
