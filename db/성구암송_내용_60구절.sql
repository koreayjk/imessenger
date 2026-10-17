-- =====================================================================
--  📜 성구암송 내용 ① — 네비게이토 주제별 성구암송 (TMS) 60구절
--
--  다섯 묶음(A~E) × 주제 여섯 × 두 구절 = 60구절.
--  한글(개역개정)과 영어(NIV)를 따로 담습니다. 같은 구절이라도 줄을
--  따로 두어, 학생이 한글로 외운 것과 영어로 외운 것을 각각 체크합니다.
--
--  한글 본문은 보내주신 그대로 넣었습니다.
--
--  ⚠️ 영어(NIV) 본문은 제가 적은 것입니다. 아이들이 이 글로 외우게
--     되니 한 번 훑어봐 주세요. 다르면 학사 → 성구암송 → 항목 관리
--     에서 고칠 수 있습니다.
--
--  ※ db/성구암송_DB설치.sql 과 db/성구암송_분류언어_DB설치.sql 을
--    먼저 실행하세요.
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
--
--  Scripture quotations marked NIV are taken from the Holy Bible,
--  New International Version®, NIV®. Copyright © 1973, 1978, 1984,
--  2011 by Biblica, Inc.® Used by permission. All rights reserved
--  worldwide.
-- =====================================================================

delete from public.memory_items where kind = 'verse' and community_id is null;

insert into public.memory_items (kind, lang, no, title, body, series, topic, community_id, sort) values
  ('verse', 'ko', 1, '고린도후서 5:17', '그런즉 누구든지 그리스도 안에 있으면 새로운 피조물이라 이전 것은 지나갔으니 보라 새 것이 되었도다', 'A. 새로운 삶', '중심되신 그리스도', null, 1),
  ('verse', 'en', 1, '2 Corinthians 5:17', 'Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!', 'A. The New Life', 'Christ the Center', null, 1),
  ('verse', 'ko', 2, '갈라디아서 2:20', '내가 그리스도와 함께 십자가에 못 박혔나니 그런즉 이제는 내가 사는 것이 아니요 오직 내 안에 그리스도께서 사시는 것이라 이제 내가 육체 가운데 사는 것은 나를 사랑하사 나를 위하여 자기 자신을 버리신 하나님의 아들을 믿는 믿음 안에서 사는 것이라', 'A. 새로운 삶', '중심되신 그리스도', null, 2),
  ('verse', 'en', 2, 'Galatians 2:20', 'I have been crucified with Christ and I no longer live, but Christ lives in me. The life I now live in the body, I live by faith in the Son of God, who loved me and gave himself for me.', 'A. The New Life', 'Christ the Center', null, 2),
  ('verse', 'ko', 3, '로마서 12:1', '그러므로 형제들아 내가 하나님의 모든 자비하심으로 너희를 권하노니 너희 몸을 하나님이 기뻐하시는 거룩한 산 제물로 드리라 이는 너희가 드릴 영적 예배니라', 'A. 새로운 삶', '그리스도께 순종', null, 3),
  ('verse', 'en', 3, 'Romans 12:1', 'Therefore, I urge you, brothers and sisters, in view of God''s mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship.', 'A. The New Life', 'Obedience to Christ', null, 3),
  ('verse', 'ko', 4, '요한복음 14:21', '나의 계명을 지키는 자라야 나를 사랑하는 자니 나를 사랑하는 자는 내 아버지께 사랑을 받을 것이요 나도 그를 사랑하여 그에게 나를 나타내리라', 'A. 새로운 삶', '그리스도께 순종', null, 4),
  ('verse', 'en', 4, 'John 14:21', 'Whoever has my commands and keeps them is the one who loves me. The one who loves me will be loved by my Father, and I too will love them and show myself to them.', 'A. The New Life', 'Obedience to Christ', null, 4),
  ('verse', 'ko', 5, '디모데후서 3:16', '모든 성경은 하나님의 감동으로 된 것으로 교훈과 책망과 바르게 함과 의로 교육하기에 유익하니', 'A. 새로운 삶', '말씀', null, 5),
  ('verse', 'en', 5, '2 Timothy 3:16', 'All Scripture is God-breathed and is useful for teaching, rebuking, correcting and training in righteousness,', 'A. The New Life', 'The Word', null, 5),
  ('verse', 'ko', 6, '여호수아 1:8', '이 율법책을 네 입에서 떠나지 말게 하며 주야로 그것을 묵상하여 그 안에 기록된 대로 다 지켜 행하라 그리하면 네 길이 평탄하게 될 것이며 네가 형통하리라', 'A. 새로운 삶', '말씀', null, 6),
  ('verse', 'en', 6, 'Joshua 1:8', 'Keep this Book of the Law always on your lips; meditate on it day and night, so that you may be careful to do everything written in it. Then you will be prosperous and successful.', 'A. The New Life', 'The Word', null, 6),
  ('verse', 'ko', 7, '요한복음 15:7', '너희가 내 안에 거하고 내 말이 너희 안에 거하면 무엇이든지 원하는 대로 구하라 그리하면 이루리라', 'A. 새로운 삶', '기도', null, 7),
  ('verse', 'en', 7, 'John 15:7', 'If you remain in me and my words remain in you, ask whatever you wish, and it will be done for you.', 'A. The New Life', 'Prayer', null, 7),
  ('verse', 'ko', 8, '빌립보서 4:6-7', '아무 것도 염려하지 말고 다만 모든 일에 기도와 간구로, 너희 구할 것을 감사함으로 하나님께 아뢰라
그리하면 모든 지각에 뛰어난 하나님의 평강이 그리스도 예수 안에서 너희 마음과 생각을 지키시리라', 'A. 새로운 삶', '기도', null, 8),
  ('verse', 'en', 8, 'Philippians 4:6-7', 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.
And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.', 'A. The New Life', 'Prayer', null, 8),
  ('verse', 'ko', 9, '마태복음 18:20', '두세 사람이 내 이름으로 모인 곳에는 나도 그들 중에 있느니라', 'A. 새로운 삶', '교제', null, 9),
  ('verse', 'en', 9, 'Matthew 18:20', 'For where two or three gather in my name, there am I with them.', 'A. The New Life', 'Fellowship', null, 9),
  ('verse', 'ko', 10, '히브리서 10:24-25', '서로 돌아보아 사랑과 선행을 격려하며
모이기를 폐하는 어떤 사람들의 습관과 같이 하지 말고 오직 권하여 그 날이 가까움을 볼수록 더욱 그리하자', 'A. 새로운 삶', '교제', null, 10),
  ('verse', 'en', 10, 'Hebrews 10:24-25', 'And let us consider how we may spur one another on toward love and good deeds,
not giving up meeting together, as some are in the habit of doing, but encouraging one another—and all the more as you see the Day approaching.', 'A. The New Life', 'Fellowship', null, 10),
  ('verse', 'ko', 11, '마태복음 4:19', '말씀하시되 나를 따라오라 내가 너희를 사람을 낚는 어부가 되게 하리라 하시니', 'A. 새로운 삶', '증거', null, 11),
  ('verse', 'en', 11, 'Matthew 4:19', '"Come, follow me," Jesus said, "and I will send you out to fish for people."', 'A. The New Life', 'Witnessing', null, 11),
  ('verse', 'ko', 12, '로마서 1:16', '내가 복음을 부끄러워하지 아니하노니 이 복음은 모든 믿는 자에게 구원을 주시는 하나님의 능력이 됨이라 먼저는 유대인에게요 그리고 헬라인에게로다', 'A. 새로운 삶', '증거', null, 12),
  ('verse', 'en', 12, 'Romans 1:16', 'For I am not ashamed of the gospel, because it is the power of God that brings salvation to everyone who believes: first to the Jew, then to the Gentile.', 'A. The New Life', 'Witnessing', null, 12),
  ('verse', 'ko', 13, '로마서 3:23', '모든 사람이 죄를 범하였으매 하나님의 영광에 이르지 못하더니', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 13),
  ('verse', 'en', 13, 'Romans 3:23', 'for all have sinned and fall short of the glory of God,', 'B. Proclaim Christ', 'All Have Sinned', null, 13),
  ('verse', 'ko', 14, '이사야 53:6', '우리는 다 양 같아서 그릇 행하여 각기 제 길로 갔거늘 여호와께서는 우리 모두의 죄악을 그에게 담당시키셨도다', 'B. 그리스도를 전파함', '모든 사람이 죄를 범함', null, 14),
  ('verse', 'en', 14, 'Isaiah 53:6', 'We all, like sheep, have gone astray, each of us has turned to our own way; and the LORD has laid on him the iniquity of us all.', 'B. Proclaim Christ', 'All Have Sinned', null, 14),
  ('verse', 'ko', 15, '로마서 6:23', '죄의 삯은 사망이요 하나님의 은사는 그리스도 예수 우리 주 안에 있는 영생이니라', 'B. 그리스도를 전파함', '죄의 형벌', null, 15),
  ('verse', 'en', 15, 'Romans 6:23', 'For the wages of sin is death, but the gift of God is eternal life in Christ Jesus our Lord.', 'B. Proclaim Christ', 'Sin''s Penalty', null, 15),
  ('verse', 'ko', 16, '히브리서 9:27', '한번 죽는 것은 사람에게 정해진 것이요 그 후에는 심판이 있으리니', 'B. 그리스도를 전파함', '죄의 형벌', null, 16),
  ('verse', 'en', 16, 'Hebrews 9:27', 'Just as people are destined to die once, and after that to face judgment,', 'B. Proclaim Christ', 'Sin''s Penalty', null, 16),
  ('verse', 'ko', 17, '로마서 5:8', '우리가 아직 죄인 되었을 때에 그리스도께서 우리를 위하여 죽으심으로 하나님께서 우리에 대한 자기의 사랑을 확증하셨느니라', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 17),
  ('verse', 'en', 17, 'Romans 5:8', 'But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 17),
  ('verse', 'ko', 18, '베드로전서 3:18', '그리스도께서도 단번에 죄를 위하여 죽으사 의인으로서 불의한 자를 대신하셨으니 이는 우리를 하나님 앞으로 인도하려 하심이라 육체로는 죽임을 당하시고 영으로는 살리심을 받으셨으니', 'B. 그리스도를 전파함', '그리스도가 형벌을 받음', null, 18),
  ('verse', 'en', 18, '1 Peter 3:18', 'For Christ also suffered once for sins, the righteous for the unrighteous, to bring you to God. He was put to death in the body but made alive in the Spirit.', 'B. Proclaim Christ', 'Christ Paid the Penalty', null, 18),
  ('verse', 'ko', 19, '에베소서 2:8-9', '너희는 그 은혜에 의하여 믿음으로 말미암아 구원을 받았으니 이것은 너희에게서 난 것이 아니요 하나님의 선물이라
행위에서 난 것이 아니니 이는 누구든지 자랑하지 못하게 함이라', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 19),
  ('verse', 'en', 19, 'Ephesians 2:8-9', 'For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—
not by works, so that no one can boast.', 'B. Proclaim Christ', 'Salvation Not by Works', null, 19),
  ('verse', 'ko', 20, '디도서 3:5', '우리를 구원하시되 우리가 행한 바 의로운 행위로 말미암지 아니하고 오직 그의 긍휼하심을 따라 중생의 씻음과 성령의 새롭게 하심으로 하셨나니', 'B. 그리스도를 전파함', '선행으로 구원받지 못함', null, 20),
  ('verse', 'en', 20, 'Titus 3:5', 'he saved us, not because of righteous things we had done, but because of his mercy. He saved us through the washing of rebirth and renewal by the Holy Spirit,', 'B. Proclaim Christ', 'Salvation Not by Works', null, 20),
  ('verse', 'ko', 21, '요한복음 1:12', '영접하는 자 곧 그 이름을 믿는 자들에게는 하나님의 자녀가 되는 권세를 주셨으니', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 21),
  ('verse', 'en', 21, 'John 1:12', 'Yet to all who did receive him, to those who believed in his name, he gave the right to become children of God—', 'B. Proclaim Christ', 'Must Receive Christ', null, 21),
  ('verse', 'ko', 22, '요한계시록 3:20', '볼지어다 내가 문 밖에 서서 두드리노니 누구든지 내 음성을 듣고 문을 열면 내가 그에게로 들어가 그와 더불어 먹고 그는 나와 더불어 먹으리라', 'B. 그리스도를 전파함', '그리스도를 모셔야 함', null, 22),
  ('verse', 'en', 22, 'Revelation 3:20', 'Here I am! I stand at the door and knock. If anyone hears my voice and opens the door, I will come in and eat with that person, and they with me.', 'B. Proclaim Christ', 'Must Receive Christ', null, 22),
  ('verse', 'ko', 23, '요한일서 5:13', '내가 하나님의 아들의 이름을 믿는 너희에게 이것을 쓰는 것은 너희로 하여금 너희에게 영생이 있음을 알게 하려 함이라', 'B. 그리스도를 전파함', '구원의 확신', null, 23),
  ('verse', 'en', 23, '1 John 5:13', 'I write these things to you who believe in the name of the Son of God so that you may know that you have eternal life.', 'B. Proclaim Christ', 'Assurance of Salvation', null, 23),
  ('verse', 'ko', 24, '요한복음 5:24', '내가 진실로 진실로 너희에게 이르노니 내 말을 듣고 또 나 보내신 이를 믿는 자는 영생을 얻었고 심판에 이르지 아니하나니 사망에서 생명으로 옮겼느니라', 'B. 그리스도를 전파함', '구원의 확신', null, 24),
  ('verse', 'en', 24, 'John 5:24', 'Very truly I tell you, whoever hears my word and believes him who sent me has eternal life and will not be judged but has crossed over from death to life.', 'B. Proclaim Christ', 'Assurance of Salvation', null, 24),
  ('verse', 'ko', 25, '고린도전서 3:16', '너희는 너희가 하나님의 성전인 것과 하나님의 성령이 너희 안에 계시는 것을 알지 못하느냐', 'C. 하나님을 의뢰함', '성령', null, 25),
  ('verse', 'en', 25, '1 Corinthians 3:16', 'Don''t you know that you yourselves are God''s temple and that God''s Spirit dwells in your midst?', 'C. Rely on God''s Resources', 'His Spirit', null, 25),
  ('verse', 'ko', 26, '고린도전서 2:12', '우리가 세상의 영을 받지 아니하고 오직 하나님으로부터 온 영을 받았으니 이는 우리로 하여금 하나님께서 우리에게 은혜로 주신 것들을 알게 하려 하심이라', 'C. 하나님을 의뢰함', '성령', null, 26),
  ('verse', 'en', 26, '1 Corinthians 2:12', 'What we have received is not the spirit of the world, but the Spirit who is from God, so that we may understand what God has freely given us.', 'C. Rely on God''s Resources', 'His Spirit', null, 26),
  ('verse', 'ko', 27, '이사야 41:10', '두려워하지 말라 내가 너와 함께 함이라 놀라지 말라 나는 네 하나님이 됨이라 내가 너를 굳세게 하리라 참으로 너를 도와 주리라 참으로 나의 의로운 오른손으로 너를 붙들리라', 'C. 하나님을 의뢰함', '능력', null, 27),
  ('verse', 'en', 27, 'Isaiah 41:10', 'So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.', 'C. Rely on God''s Resources', 'His Strength', null, 27),
  ('verse', 'ko', 28, '빌립보서 4:13', '내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라', 'C. 하나님을 의뢰함', '능력', null, 28),
  ('verse', 'en', 28, 'Philippians 4:13', 'I can do all this through him who gives me strength.', 'C. Rely on God''s Resources', 'His Strength', null, 28),
  ('verse', 'ko', 29, '예레미야애가 3:22-23', '여호와의 인자와 긍휼이 무궁하시므로 우리가 진멸되지 아니함이니이다
이것들이 아침마다 새로우니 주의 성실하심이 크시도소이다', 'C. 하나님을 의뢰함', '성실', null, 29),
  ('verse', 'en', 29, 'Lamentations 3:22-23', 'Because of the LORD''s great love we are not consumed, for his compassions never fail.
They are new every morning; great is your faithfulness.', 'C. Rely on God''s Resources', 'His Faithfulness', null, 29),
  ('verse', 'ko', 30, '민수기 23:19', '하나님은 사람이 아니시니 거짓말을 하지 않으시고 인생이 아니시니 후회가 없으시도다 어찌 그 말씀하신 바를 행하지 않으시며 하신 말씀을 실행하지 않으시랴', 'C. 하나님을 의뢰함', '성실', null, 30),
  ('verse', 'en', 30, 'Numbers 23:19', 'God is not human, that he should lie, not a human being, that he should change his mind. Does he speak and then not act? Does he promise and not fulfill?', 'C. Rely on God''s Resources', 'His Faithfulness', null, 30),
  ('verse', 'ko', 31, '이사야 26:3', '주께서 심지가 견고한 자를 평강하고 평강하도록 지키시리니 이는 그가 주를 신뢰함이니이다', 'C. 하나님을 의뢰함', '평안', null, 31),
  ('verse', 'en', 31, 'Isaiah 26:3', 'You will keep in perfect peace those whose minds are steadfast, because they trust in you.', 'C. Rely on God''s Resources', 'His Peace', null, 31),
  ('verse', 'ko', 32, '베드로전서 5:7', '너희 염려를 다 주께 맡기라 이는 그가 너희를 돌보심이라', 'C. 하나님을 의뢰함', '평안', null, 32),
  ('verse', 'en', 32, '1 Peter 5:7', 'Cast all your anxiety on him because he cares for you.', 'C. Rely on God''s Resources', 'His Peace', null, 32),
  ('verse', 'ko', 33, '로마서 8:32', '자기 아들을 아끼지 아니하시고 우리 모든 사람을 위하여 내주신 이가 어찌 그 아들과 함께 모든 것을 우리에게 주시지 아니하겠느냐', 'C. 하나님을 의뢰함', '공급', null, 33),
  ('verse', 'en', 33, 'Romans 8:32', 'He who did not spare his own Son, but gave him up for us all—how will he not also, along with him, graciously give us all things?', 'C. Rely on God''s Resources', 'His Provision', null, 33),
  ('verse', 'ko', 34, '빌립보서 4:19', '나의 하나님이 그리스도 예수 안에서 영광 가운데 그 풍성한 대로 너희 모든 쓸 것을 채우시리라', 'C. 하나님을 의뢰함', '공급', null, 34),
  ('verse', 'en', 34, 'Philippians 4:19', 'And my God will meet all your needs according to the riches of his glory in Christ Jesus.', 'C. Rely on God''s Resources', 'His Provision', null, 34),
  ('verse', 'ko', 35, '히브리서 2:18', '그가 시험을 받아 고난을 당하셨은즉 시험 받는 자들을 능히 도우실 수 있느니라', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 35),
  ('verse', 'en', 35, 'Hebrews 2:18', 'Because he himself suffered when he was tempted, he is able to help those who are being tempted.', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 35),
  ('verse', 'ko', 36, '시편 119:9,11', '청년이 무엇으로 그의 행실을 깨끗하게 하리이까 주의 말씀만 지킬 따름이니이다
내가 주께 범죄하지 아니하려 하여 주의 말씀을 내 마음에 두었나이다', 'C. 하나님을 의뢰함', '유혹에서 도우심', null, 36),
  ('verse', 'en', 36, 'Psalm 119:9,11', 'How can a young person stay on the path of purity? By living according to your word.
I have hidden your word in my heart that I might not sin against you.', 'C. Rely on God''s Resources', 'His Help in Temptation', null, 36),
  ('verse', 'ko', 37, '마태복음 6:33', '그런즉 너희는 먼저 그의 나라와 그의 의를 구하라 그리하면 이 모든 것을 너희에게 더하시리라', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 37),
  ('verse', 'en', 37, 'Matthew 6:33', 'But seek first his kingdom and his righteousness, and all these things will be given to you as well.', 'D. Be Christ''s Disciple', 'Put Christ First', null, 37),
  ('verse', 'ko', 38, '누가복음 9:23', '또 무리에게 이르시되 아무든지 나를 따라오려거든 자기를 부인하고 날마다 제 십자가를 지고 나를 따를 것이니라', 'D. 그리스도 제자의 자격', '그리스도를 첫자리에 모심', null, 38),
  ('verse', 'en', 38, 'Luke 9:23', 'Then he said to them all: "Whoever wants to be my disciple must deny themselves and take up their cross daily and follow me."', 'D. Be Christ''s Disciple', 'Put Christ First', null, 38),
  ('verse', 'ko', 39, '요한일서 2:15-16', '이 세상이나 세상에 있는 것들을 사랑하지 말라 누구든지 세상을 사랑하면 아버지의 사랑이 그 안에 있지 아니하니
이는 세상에 있는 모든 것이 육신의 정욕과 안목의 정욕과 이생의 자랑이니 다 아버지께로부터 온 것이 아니요 세상으로부터 온 것이라', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 39),
  ('verse', 'en', 39, '1 John 2:15-16', 'Do not love the world or anything in the world. If anyone loves the world, love for the Father is not in them.
For everything in the world—the lust of the flesh, the lust of the eyes, and the pride of life—comes not from the Father but from the world.', 'D. Be Christ''s Disciple', 'Separate from the World', null, 39),
  ('verse', 'ko', 40, '로마서 12:2', '너희는 이 세대를 본받지 말고 오직 마음을 새롭게 함으로 변화를 받아 하나님의 선하시고 기뻐하시고 온전하신 뜻이 무엇인지 분별하도록 하라', 'D. 그리스도 제자의 자격', '죄에서 떠남', null, 40),
  ('verse', 'en', 40, 'Romans 12:2', 'Do not conform to the pattern of this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what God''s will is—his good, pleasing and perfect will.', 'D. Be Christ''s Disciple', 'Separate from the World', null, 40),
  ('verse', 'ko', 41, '고린도전서 15:58', '그러므로 내 사랑하는 형제들아 견실하며 흔들리지 말고 항상 주의 일에 더욱 힘쓰는 자들이 되라 이는 너희 수고가 주 안에서 헛되지 않은 줄 앎이라', 'D. 그리스도 제자의 자격', '견고함', null, 41),
  ('verse', 'en', 41, '1 Corinthians 15:58', 'Therefore, my dear brothers and sisters, stand firm. Let nothing move you. Always give yourselves fully to the work of the Lord, because you know that your labor in the Lord is not in vain.', 'D. Be Christ''s Disciple', 'Steadfast', null, 41),
  ('verse', 'ko', 42, '히브리서 12:3', '너희가 피곤하여 낙심하지 않기 위하여 죄인들이 이같이 자기에게 거역한 일을 참으신 이를 생각하라', 'D. 그리스도 제자의 자격', '견고함', null, 42),
  ('verse', 'en', 42, 'Hebrews 12:3', 'Consider him who endured such opposition from sinners, so that you will not grow weary and lose heart.', 'D. Be Christ''s Disciple', 'Steadfast', null, 42),
  ('verse', 'ko', 43, '마가복음 10:45', '인자가 온 것은 섬김을 받으려 함이 아니라 도리어 섬기려 하고 자기 목숨을 많은 사람의 대속물로 주려 함이니라', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 43),
  ('verse', 'en', 43, 'Mark 10:45', 'For even the Son of Man did not come to be served, but to serve, and to give his life as a ransom for many.', 'D. Be Christ''s Disciple', 'Serve Others', null, 43),
  ('verse', 'ko', 44, '고린도후서 4:5', '우리는 우리를 전파하는 것이 아니라 오직 그리스도 예수의 주 되신 것과 또 예수를 위하여 우리가 너희의 종 된 것을 전파함이라', 'D. 그리스도 제자의 자격', '다른 사람을 섬김', null, 44),
  ('verse', 'en', 44, '2 Corinthians 4:5', 'For what we preach is not ourselves, but Jesus Christ as Lord, and ourselves as your servants for Jesus'' sake.', 'D. Be Christ''s Disciple', 'Serve Others', null, 44),
  ('verse', 'ko', 45, '잠언 3:9-10', '네 재물과 네 소산물의 처음 익은 열매로 여호와를 공경하라
그리하면 네 창고가 가득히 차고 네 포도즙 틀에 새 포도즙이 넘치리라', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 45),
  ('verse', 'en', 45, 'Proverbs 3:9-10', 'Honor the LORD with your wealth, with the firstfruits of all your crops;
then your barns will be filled to overflowing, and your vats will brim over with new wine.', 'D. Be Christ''s Disciple', 'Give Generously', null, 45),
  ('verse', 'ko', 46, '고린도후서 9:6-7', '이것이 곧 적게 심는 자는 적게 거두고 많이 심는 자는 많이 거둔다 하는 말이로다
각각 그 마음에 정한 대로 할 것이요 인색함으로나 억지로 하지 말지니 하나님은 즐겨 내는 자를 사랑하시느니라', 'D. 그리스도 제자의 자격', '후히 드릴 것', null, 46),
  ('verse', 'en', 46, '2 Corinthians 9:6-7', 'Remember this: Whoever sows sparingly will also reap sparingly, and whoever sows generously will also reap generously.
Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.', 'D. Be Christ''s Disciple', 'Give Generously', null, 46),
  ('verse', 'ko', 47, '사도행전 1:8', '오직 성령이 너희에게 임하시면 너희가 권능을 받고 예루살렘과 온 유대와 사마리아와 땅 끝까지 이르러 내 증인이 되리라 하시니라', 'D. 그리스도 제자의 자격', '세계 비전', null, 47),
  ('verse', 'en', 47, 'Acts 1:8', 'But you will receive power when the Holy Spirit comes on you; and you will be my witnesses in Jerusalem, and in all Judea and Samaria, and to the ends of the earth.', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 47),
  ('verse', 'ko', 48, '마태복음 28:19-20', '그러므로 너희는 가서 모든 민족을 제자로 삼아 아버지와 아들과 성령의 이름으로 세례를 베풀고
내가 너희에게 분부한 모든 것을 가르쳐 지키게 하라 볼지어다 내가 세상 끝날까지 너희와 항상 함께 있으리라 하시니라', 'D. 그리스도 제자의 자격', '세계 비전', null, 48),
  ('verse', 'en', 48, 'Matthew 28:19-20', 'Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit,
and teaching them to obey everything I have commanded you. And surely I am with you always, to the very end of the age.', 'D. Be Christ''s Disciple', 'Develop World Vision', null, 48),
  ('verse', 'ko', 49, '요한복음 13:34-35', '새 계명을 너희에게 주노니 서로 사랑하라 내가 너희를 사랑한 것 같이 너희도 서로 사랑하라
너희가 서로 사랑하면 이로써 모든 사람이 너희가 내 제자인 줄 알리라', 'E. 그리스도를 닮아감', '사랑', null, 49),
  ('verse', 'en', 49, 'John 13:34-35', 'A new command I give you: Love one another. As I have loved you, so you must love one another.
By this everyone will know that you are my disciples, if you love one another.', 'E. Grow in Christlikeness', 'Love', null, 49),
  ('verse', 'ko', 50, '요한일서 3:18', '자녀들아 우리가 말과 혀로만 사랑하지 말고 행함과 진실함으로 하자', 'E. 그리스도를 닮아감', '사랑', null, 50),
  ('verse', 'en', 50, '1 John 3:18', 'Dear children, let us not love with words or speech but with actions and in truth.', 'E. Grow in Christlikeness', 'Love', null, 50),
  ('verse', 'ko', 51, '빌립보서 2:3-4', '아무 일에든지 다툼이나 허영으로 하지 말고 오직 겸손한 마음으로 각각 자기보다 남을 낫게 여기고
각각 자기 일을 돌볼뿐더러 또한 각각 다른 사람들의 일을 돌보아 나의 기쁨을 충만하게 하라', 'E. 그리스도를 닮아감', '겸손', null, 51),
  ('verse', 'en', 51, 'Philippians 2:3-4', 'Do nothing out of selfish ambition or vain conceit. Rather, in humility value others above yourselves,
not looking to your own interests but each of you to the interests of the others.', 'E. Grow in Christlikeness', 'Humility', null, 51),
  ('verse', 'ko', 52, '베드로전서 5:5-6', '젊은 자들아 이와 같이 장로들에게 순종하고 다 서로 겸손으로 허리를 동이라 하나님은 교만한 자를 대적하시되 겸손한 자들에게는 은혜를 주시느니라
그러므로 하나님의 능하신 손 아래에서 겸손하라 때가 되면 너희를 높이시리라', 'E. 그리스도를 닮아감', '겸손', null, 52),
  ('verse', 'en', 52, '1 Peter 5:5-6', 'In the same way, you who are younger, submit yourselves to your elders. All of you, clothe yourselves with humility toward one another, because, "God opposes the proud but shows favor to the humble."
Humble yourselves, therefore, under God''s mighty hand, that he may lift you up in due time.', 'E. Grow in Christlikeness', 'Humility', null, 52),
  ('verse', 'ko', 53, '에베소서 5:3', '음행과 온갖 더러운 것과 탐욕은 너희 중에서 그 이름조차도 부르지 말라 이는 성도에게 마땅한 바니라', 'E. 그리스도를 닮아감', '순결', null, 53),
  ('verse', 'en', 53, 'Ephesians 5:3', 'But among you there must not be even a hint of sexual immorality, or of any kind of impurity, or of greed, because these are improper for God''s holy people.', 'E. Grow in Christlikeness', 'Purity', null, 53),
  ('verse', 'ko', 54, '베드로전서 2:11', '사랑하는 자들아 거류민과 나그네 같은 너희를 권하노니 영혼을 거슬러 싸우는 육체의 정욕을 제어하라', 'E. 그리스도를 닮아감', '순결', null, 54),
  ('verse', 'en', 54, '1 Peter 2:11', 'Dear friends, I urge you, as foreigners and exiles, to abstain from sinful desires, which wage war against your soul.', 'E. Grow in Christlikeness', 'Purity', null, 54),
  ('verse', 'ko', 55, '레위기 19:11', '너희는 도둑질하지 말며 속이지 말며 서로 거짓말하지 말며', 'E. 그리스도를 닮아감', '정직', null, 55),
  ('verse', 'en', 55, 'Leviticus 19:11', 'Do not steal. Do not lie. Do not deceive one another.', 'E. Grow in Christlikeness', 'Honesty', null, 55),
  ('verse', 'ko', 56, '사도행전 24:16', '이것으로 말미암아 나도 하나님과 사람에 대하여 항상 양심에 거리낌이 없기를 힘쓰나이다', 'E. 그리스도를 닮아감', '정직', null, 56),
  ('verse', 'en', 56, 'Acts 24:16', 'So I strive always to keep my conscience clear before God and man.', 'E. Grow in Christlikeness', 'Honesty', null, 56),
  ('verse', 'ko', 57, '히브리서 11:6', '믿음이 없이는 하나님을 기쁘시게 하지 못하나니 하나님께 나아가는 자는 반드시 그가 계신 것과 또한 그가 자기를 찾는 자들에게 상 주시는 이심을 믿어야 할지니라', 'E. 그리스도를 닮아감', '믿음', null, 57),
  ('verse', 'en', 57, 'Hebrews 11:6', 'And without faith it is impossible to please God, because anyone who comes to him must believe that he exists and that he rewards those who earnestly seek him.', 'E. Grow in Christlikeness', 'Faith', null, 57),
  ('verse', 'ko', 58, '로마서 4:20-21', '믿음이 없어 하나님의 약속을 의심하지 않고 믿음으로 견고하여져서 하나님께 영광을 돌리며
약속하신 그것을 또한 능히 이루실 줄을 확신하였으니', 'E. 그리스도를 닮아감', '믿음', null, 58),
  ('verse', 'en', 58, 'Romans 4:20-21', 'Yet he did not waver through unbelief regarding the promise of God, but was strengthened in his faith and gave glory to God,
being fully persuaded that God had power to do what he had promised.', 'E. Grow in Christlikeness', 'Faith', null, 58),
  ('verse', 'ko', 59, '갈라디아서 6:9-10', '우리가 선을 행하되 낙심하지 말지니 포기하지 아니하면 때가 이르매 거두리라
그러므로 우리는 기회 있는 대로 모든 이에게 착한 일을 하되 더욱 믿음의 가정들에게 할지니라', 'E. 그리스도를 닮아감', '선행', null, 59),
  ('verse', 'en', 59, 'Galatians 6:9-10', 'Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.
Therefore, as we have opportunity, let us do good to all people, especially to those who belong to the family of believers.', 'E. Grow in Christlikeness', 'Good Works', null, 59),
  ('verse', 'ko', 60, '마태복음 5:16', '이같이 너희 빛이 사람 앞에 비치게 하여 그들로 너희 착한 행실을 보고 하늘에 계신 너희 아버지께 영광을 돌리게 하라', 'E. 그리스도를 닮아감', '선행', null, 60),
  ('verse', 'en', 60, 'Matthew 5:16', 'In the same way, let your light shine before others, that they may see your good deeds and glorify your Father in heaven.', 'E. Grow in Christlikeness', 'Good Works', null, 60);

notify pgrst, 'reload schema';

-- ── 확인 ─────────────────────────────────────────────────────────
select lang as "말", count(*) as "구절", count(distinct series) as "묶음", count(distinct topic) as "주제"
  from public.memory_items where kind='verse' group by 1 order by 1;

select series as "묶음", count(*) filter (where lang='ko') as "한글", count(*) filter (where lang='en') as "영어"
  from public.memory_items where kind='verse' group by 1 order by 1;
