-- =====================================================================
--  Triple School 독서 도서목록 (Step 1~4 · Gospel/Disciple/Calling)
--  Supabase → SQL Editor 에 붙여넣고 한 번 실행하세요. (재실행해도 안전)
-- =====================================================================
alter table public.reading_books add column if not exists step smallint;
alter table public.reading_books add column if not exists publisher text;

insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Gospel School','God''s Great Plan Storybook Bible','Cecilie Fodor','Life Book',0
where not exists (select 1 from public.reading_books where title='God''s Great Plan Storybook Bible' and step=1 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Gospel School','Joseph With God','Jiyoung Lee','Covenant Books',1
where not exists (select 1 from public.reading_books where title='Joseph With God' and step=1 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Gospel School','The Way of Salvation ABC','Oiyoung Yu','Covenant Books',2
where not exists (select 1 from public.reading_books where title='The Way of Salvation ABC' and step=1 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Gospel School','The Gospel Story Bible','Marty Machowski','Junior Agape',3
where not exists (select 1 from public.reading_books where title='The Gospel Story Bible' and step=1 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Gospel School','The Promise','Carine McKenzie','Our times',4
where not exists (select 1 from public.reading_books where title='The Promise' and step=1 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','The Ten Faith Stepping-stone','Oiyoung Yu','Covenant Books',5
where not exists (select 1 from public.reading_books where title='The Ten Faith Stepping-stone' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','The Ology','Marty Machowski','Life Book',6
where not exists (select 1 from public.reading_books where title='The Ology' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 1. My Most Important Thing','Oiyoung Yu','Covenant Books',7
where not exists (select 1 from public.reading_books where title='Jesus is Christ 1. My Most Important Thing' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 2. Who is the Main Character in the Bible?','Oiyoung Yu','Covenant Books',8
where not exists (select 1 from public.reading_books where title='Jesus is Christ 2. Who is the Main Character in the Bible?' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 3. God Three in One','Oiyoung Yu','Covenant Books',9
where not exists (select 1 from public.reading_books where title='Jesus is Christ 3. God Three in One' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 4. Whole World Created for Jesus','Oiyoung Yu','Covenant Books',10
where not exists (select 1 from public.reading_books where title='Jesus is Christ 4. Whole World Created for Jesus' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 5. The Creation of Man and Woman','Oiyoung Yu','Covenant Books',11
where not exists (select 1 from public.reading_books where title='Jesus is Christ 5. The Creation of Man and Woman' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 6. I Want it My Way!','Oiyoung Yu','Covenant Books',12
where not exists (select 1 from public.reading_books where title='Jesus is Christ 6. I Want it My Way!' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 7. Wait, God became a Man?','Oiyoung Yu','Covenant Books',13
where not exists (select 1 from public.reading_books where title='Jesus is Christ 7. Wait, God became a Man?' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 8. Jesus is my Christ','Oiyoung Yu','Covenant Books',14
where not exists (select 1 from public.reading_books where title='Jesus is Christ 8. Jesus is my Christ' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 9. I am God''s Temple','Sue Kim','Covenant Books',15
where not exists (select 1 from public.reading_books where title='Jesus is Christ 9. I am God''s Temple' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','Jesus is Christ 10. God''s Greatest Masterpiece','Sukyung Kim','Covenant Books',16
where not exists (select 1 from public.reading_books where title='Jesus is Christ 10. God''s Greatest Masterpiece' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','The Lord''s Prayer for Young Children','Eunkyeong Seo','Life Book',17
where not exists (select 1 from public.reading_books where title='The Lord''s Prayer for Young Children' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','The Apostle''s Creed for Young Children','Eunkyeong Seo','Life Book',18
where not exists (select 1 from public.reading_books where title='The Apostle''s Creed for Young Children' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Disciple School','The Ten Commandments for Young Children','Eunkyeong Seo','Life Book',19
where not exists (select 1 from public.reading_books where title='The Ten Commandments for Young Children' and step=1 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','100 People of Faith who enlightened God''s Kingdom','Oiyoung Yu','Covenant Books',20
where not exists (select 1 from public.reading_books where title='100 People of Faith who enlightened God''s Kingdom' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set. Abraham','Eunju Choi','Covenant Books',21
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set. Abraham' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Moses','Jiyoung Lee, Oiyoung Yu','Covenant Books',22
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Moses' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Joseph','Oiyoung Yu','Covenant Books',23
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Joseph' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Samuel','Eunsung Lee, Oiyoung Yu','Covenant Books',24
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Samuel' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, David','Donghoon Jung, Oiyoung Yu','Covenant Books',25
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, David' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Isaiah','Oiyoung Yu','Covenant Books',26
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Isaiah' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Elisha','Oiyoung Yu','Covenant Books',27
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Elisha' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Daniel','Eunju Choi','Covenant Books',28
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Daniel' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Esther','Eunju Choi','Covenant Books',29
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Esther' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','The Dream of Covenant Set, Paul','Eunsung Lee, Oiyoung Yu','Covenant Books',30
where not exists (select 1 from public.reading_books where title='The Dream of Covenant Set, Paul' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','Sex Education in The Bible','IM BOOKS','IM BOOKS',31
where not exists (select 1 from public.reading_books where title='Sex Education in The Bible' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','God Made Boys and Girls','Marty Machowski','Home and Edu',32
where not exists (select 1 from public.reading_books where title='God Made Boys and Girls' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 1,'Calling School','Dinosaurs of Eden','Ken Ham','Dreams Come True',33
where not exists (select 1 from public.reading_books where title='Dinosaurs of Eden' and step=1 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','14 days of The Old Testament Journey','IM BOOKS','IM BOOKS',34
where not exists (select 1 from public.reading_books where title='14 days of The Old Testament Journey' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','Main Characters of 66 Books of the Bible, Praise Jesus','Oiyoung Yu','Covenant Books',35
where not exists (select 1 from public.reading_books where title='Main Characters of 66 Books of the Bible, Praise Jesus' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','What? I Can Read the Bible The Old Testament Episode: The Comic','Aesil Lee','Life Book',36
where not exists (select 1 from public.reading_books where title='What? I Can Read the Bible The Old Testament Episode: The Comic' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','What? I can Read the Bible The New Testament Episode: The Comic','Aesil Lee','Life Book',37
where not exists (select 1 from public.reading_books where title='What? I can Read the Bible The New Testament Episode: The Comic' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','The Story of The Kingdom of God','IM BOOKS','IM BOOKS',38
where not exists (select 1 from public.reading_books where title='The Story of The Kingdom of God' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','Salvation and God''s Plan: The Comic','Namjun Kim','Revival & Reformation',39
where not exists (select 1 from public.reading_books where title='Salvation and God''s Plan: The Comic' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Gospel School','The Promise','IM BOOKS','IM BOOKS',40
where not exists (select 1 from public.reading_books where title='The Promise' and step=2 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','The Apostle''s Creed: The Comic','Geumsan Baek','Revival & Reformation',41
where not exists (select 1 from public.reading_books where title='The Apostle''s Creed: The Comic' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','The Ten Commandments: The comic','Geumsan Baek','Revival & Reformation',42
where not exists (select 1 from public.reading_books where title='The Ten Commandments: The comic' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','The Lord''s Prayer: The Comic','Geumsan Baek','Revival & Reformation',43
where not exists (select 1 from public.reading_books where title='The Lord''s Prayer: The Comic' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','The Way the People of God''s Kingdom Live','IM BOOKS','IM BOOKS',44
where not exists (select 1 from public.reading_books where title='The Way the People of God''s Kingdom Live' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','The Pilgrim''s Progress in One Breath','Hongman Kim','Life Book',45
where not exists (select 1 from public.reading_books where title='The Pilgrim''s Progress in One Breath' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Disciple School','A Faulty Faith of A Good Christian for Kids','IM BOOKS','IM BOOKS',46
where not exists (select 1 from public.reading_books where title='A Faulty Faith of A Good Christian for Kids' and step=2 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','The Family for Children','Namjun Kim, YL Junior Team','Life Book',47
where not exists (select 1 from public.reading_books where title='The Family for Children' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Ten Boys Who Changed The World','Irene Howat','Togijangi Book',48
where not exists (select 1 from public.reading_books where title='Ten Boys Who Changed The World' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Ten Boys Who Made History','Irene Howat','Togijangi Book',49
where not exists (select 1 from public.reading_books where title='Ten Boys Who Made History' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Ten Boys Who Made a Difference','Irene Howat','Togijangi Book',50
where not exists (select 1 from public.reading_books where title='Ten Boys Who Made a Difference' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Ten Boys Who Didn''t Give In','Irene Howat','Togijangi Book',51
where not exists (select 1 from public.reading_books where title='Ten Boys Who Didn''t Give In' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Ten Boys Who Used Their Talents','Irene Howat','Togijangi Book',52
where not exists (select 1 from public.reading_books where title='Ten Boys Who Used Their Talents' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','A Great Missionary','David Shivley','Dream Come True',53
where not exists (select 1 from public.reading_books where title='A Great Missionary' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Church Handbook','Dukjong kim','Good Seed Book',54
where not exists (select 1 from public.reading_books where title='Church Handbook' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Before You Say There is No God','Youngduk Park','IVP',55
where not exists (select 1 from public.reading_books where title='Before You Say There is No God' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Special Lecture on Worldview that Christian Youths must know','Soyoung Jung','Future Books CROSS',56
where not exists (select 1 from public.reading_books where title='Special Lecture on Worldview that Christian Youths must know' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Guide to Creation','Institute for Creation Research','Life Book',57
where not exists (select 1 from public.reading_books where title='Guide to Creation' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 2,'Calling School','Guide to The Human Body','Institute for Creation Research','Life Book',58
where not exists (select 1 from public.reading_books where title='Guide to The Human Body' and step=2 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','14 days of The Old Testament Journey','IM BOOKS','IM BOOKS',59
where not exists (select 1 from public.reading_books where title='14 days of The Old Testament Journey' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','Newly Met Salvation History','IM BOOKS','IM BOOKS',60
where not exists (select 1 from public.reading_books where title='Newly Met Salvation History' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Comic Bible Overview at a Glance- The Old Testament Episode','Geumsan Baek','Revival & Reformation',61
where not exists (select 1 from public.reading_books where title='The Comic Bible Overview at a Glance- The Old Testament Episode' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Comic Bible Overview at a Glance- The New Testament Episode','Geumsan Baek','Revival & Reformation',62
where not exists (select 1 from public.reading_books where title='The Comic Bible Overview at a Glance- The New Testament Episode' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Story of The Kingdom of God','IM BOOKS','IM BOOKS',63
where not exists (select 1 from public.reading_books where title='The Story of The Kingdom of God' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Promise','IM BOOKS','IM BOOKS',64
where not exists (select 1 from public.reading_books where title='The Promise' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','What Does it Mean to Be Born Again?','R. C. Sproul','Life Book',65
where not exists (select 1 from public.reading_books where title='What Does it Mean to Be Born Again?' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Christ of Christmas: James Montgomery Boice','James Montgomery Boice','Reformed Theology Books',66
where not exists (select 1 from public.reading_books where title='The Christ of Christmas: James Montgomery Boice' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Gospel School','The Christ of the Empty Tomb: James Montgomery Boice','James Montgomery Boice','Reformed Theology Books',67
where not exists (select 1 from public.reading_books where title='The Christ of the Empty Tomb: James Montgomery Boice' and step=3 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','The Comic Westminster Shorter Catechism 1','Geumsan Baek','Revival & Reformation',68
where not exists (select 1 from public.reading_books where title='The Comic Westminster Shorter Catechism 1' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','The Comic Westminster Shorter Catechism 2','Geumsan Baek','Revival & Reformation',69
where not exists (select 1 from public.reading_books where title='The Comic Westminster Shorter Catechism 2' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','Consider Jesus','Octavius Winslow','Life Book',70
where not exists (select 1 from public.reading_books where title='Consider Jesus' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','Guarding Your Heart','Arthur Pink','Prisrary',71
where not exists (select 1 from public.reading_books where title='Guarding Your Heart' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','The Way the People of God''s Kingdom Live','IM BOOKS','IM BOOKS',72
where not exists (select 1 from public.reading_books where title='The Way the People of God''s Kingdom Live' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','Life Principles of Christians','IM BOOKS','IM BOOKS',73
where not exists (select 1 from public.reading_books where title='Life Principles of Christians' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','What Would Jesus Do?','Charles Sheldon','CH Books',74
where not exists (select 1 from public.reading_books where title='What Would Jesus Do?' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','The Comic Jonathan Edwards','Geumsan Baek','Revival & Reformation',75
where not exists (select 1 from public.reading_books where title='The Comic Jonathan Edwards' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','The Comic Lloyd Jones','Geumsan Baek','Revival & Reformation',76
where not exists (select 1 from public.reading_books where title='The Comic Lloyd Jones' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Disciple School','Let Us Pray','John MacArthur, John Piper','Life Book',77
where not exists (select 1 from public.reading_books where title='Let Us Pray' and step=3 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','Raising Children God''s Way','Martyn Lloyd-Jones','Life Book',78
where not exists (select 1 from public.reading_books where title='Raising Children God''s Way' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','Work and Our Labor in the Lord','James Hamilton','Life Book',79
where not exists (select 1 from public.reading_books where title='Work and Our Labor in the Lord' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','The Comic Apostle''s Creed 1','Muhyun Lee','Life Book',80
where not exists (select 1 from public.reading_books where title='The Comic Apostle''s Creed 1' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','The Comic Apostle''s Creed 2','Muhyun Lee','Life Book',81
where not exists (select 1 from public.reading_books where title='The Comic Apostle''s Creed 2' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','The Comic Apostle''s Creed 3','Muhyun Lee','Life Book',82
where not exists (select 1 from public.reading_books where title='The Comic Apostle''s Creed 3' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','Our Guilty Silence','John Stott','IVP',83
where not exists (select 1 from public.reading_books where title='Our Guilty Silence' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','Ecclesiology: The Comics','Geumsan Baek','Revival & Reformation',84
where not exists (select 1 from public.reading_books where title='Ecclesiology: The Comics' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','Eschatology: The Comics','Geumsan Baek','Revival & Reformation',85
where not exists (select 1 from public.reading_books where title='Eschatology: The Comics' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 3,'Calling School','The Screwtape Letters','C. S. Lewis','Hongsung Books',86
where not exists (select 1 from public.reading_books where title='The Screwtape Letters' and step=3 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','Saved From What?','R. C. Sproul','Life Book',87
where not exists (select 1 from public.reading_books where title='Saved From What?' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','The Gospel As Center','D. A. Carson, Timothy Keller','Agape Books',88
where not exists (select 1 from public.reading_books where title='The Gospel As Center' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','Jesus On Every Page','David Murray','Life Book',89
where not exists (select 1 from public.reading_books where title='Jesus On Every Page' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','Gospel and Kingdom','Graeme Goldsworthy','Scripture Union Korea',90
where not exists (select 1 from public.reading_books where title='Gospel and Kingdom' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','The Promises of GOD','R. C. Sproul','Life Book',91
where not exists (select 1 from public.reading_books where title='The Promises of GOD' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Gospel School','Can I Be Sure I''m Saved?','R. C. Sproul','Life Book',92
where not exists (select 1 from public.reading_books where title='Can I Be Sure I''m Saved?' and step=4 and category='Gospel School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Seeing Christ In The Tabernacle','Ervin. N. Hershberger','IM BOOKS',93
where not exists (select 1 from public.reading_books where title='Seeing Christ In The Tabernacle' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Essential Truths of the Christian Faith','R. C. Sproul','Life Book',94
where not exists (select 1 from public.reading_books where title='Essential Truths of the Christian Faith' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Saving Faith','Arthur Pink','Life Book',95
where not exists (select 1 from public.reading_books where title='Saving Faith' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Seven Words from The Cross','Namjun Kim','Life Book',96
where not exists (select 1 from public.reading_books where title='Seven Words from The Cross' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','The Holy Spirit','R. C. Sproul','Life Book',97
where not exists (select 1 from public.reading_books where title='The Holy Spirit' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Godly Self-Control','A. T. Pierson','Life Book',98
where not exists (select 1 from public.reading_books where title='Godly Self-Control' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','The Freedom of Self-Forgetfulness','Timothy Keller','Blessed Publisher',99
where not exists (select 1 from public.reading_books where title='The Freedom of Self-Forgetfulness' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','The Practice of Piety','Lewis Bayly','Life Book',100
where not exists (select 1 from public.reading_books where title='The Practice of Piety' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','Stop Trying To Live For Jesus','Charles Price','Life Book',101
where not exists (select 1 from public.reading_books where title='Stop Trying To Live For Jesus' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','The Pilgrim''s Progress Explained','Hongman Kim','Life Book',102
where not exists (select 1 from public.reading_books where title='The Pilgrim''s Progress Explained' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Disciple School','The Life and Diary of David Brainerd','Jonathan Edwards','Life Book',103
where not exists (select 1 from public.reading_books where title='The Life and Diary of David Brainerd' and step=4 and category='Disciple School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Don''t Waste Your Life','John Piper','Life Book',104
where not exists (select 1 from public.reading_books where title='Don''t Waste Your Life' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Household Salvation','Namjun Kim','Revival & Reformation',105
where not exists (select 1 from public.reading_books where title='Household Salvation' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Duties of Parents','J. C. Ryle','Blessed Publisher',106
where not exists (select 1 from public.reading_books where title='The Duties of Parents' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Every Good Endeavor','Timothy Keller','Duranno Books',107
where not exists (select 1 from public.reading_books where title='Every Good Endeavor' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Philosophy of The Christian Curriculum','Rousas John Rushdoony','Dream Come True',108
where not exists (select 1 from public.reading_books where title='The Philosophy of The Christian Curriculum' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Living in The Light: Money, Sex and Power','John Piper','Life Book',109
where not exists (select 1 from public.reading_books where title='Living in The Light: Money, Sex and Power' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Christian Mission in the Modern World','John Stott','IVP',110
where not exists (select 1 from public.reading_books where title='Christian Mission in the Modern World' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Perspectives On The Christian Movement: Reader','Ralph Winter','YWAM Korea',111
where not exists (select 1 from public.reading_books where title='Perspectives On The Christian Movement: Reader' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Perspectives On The Christian Movement: Study Guide','Ralph Winter','YWAM Korea',112
where not exists (select 1 from public.reading_books where title='Perspectives On The Christian Movement: Study Guide' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','From Jerusalem to Irian Jaya','Ruth Tucker','Blessed Publisher',113
where not exists (select 1 from public.reading_books where title='From Jerusalem to Irian Jaya' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic History of the Early Church 1','Yohan Seo','Revival & Reformation',114
where not exists (select 1 from public.reading_books where title='The Comic History of the Early Church 1' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic History of the Early Church 2','Yohan Seo','Revival & Reformation',115
where not exists (select 1 from public.reading_books where title='The Comic History of the Early Church 2' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic Medieval Church 1','Yohan Seo','Revival & Reformation',116
where not exists (select 1 from public.reading_books where title='The Comic Medieval Church 1' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic Medieval Church 2','Yohan Seo','Revival & Reformation',117
where not exists (select 1 from public.reading_books where title='The Comic Medieval Church 2' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','Church and Remaining Christ''s Suffering','Namjun Kim','Life Book',118
where not exists (select 1 from public.reading_books where title='Church and Remaining Christ''s Suffering' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic Revelation 1','Geumsan Baek','Revival & Reformation',119
where not exists (select 1 from public.reading_books where title='The Comic Revelation 1' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Comic Revelation 2','Geumsan Baek','Revival & Reformation',120
where not exists (select 1 from public.reading_books where title='The Comic Revelation 2' and step=4 and category='Calling School');
insert into public.reading_books (step, category, title, author, publisher, sort)
select 4,'Calling School','The Universe Next Door: A Basic Worldview Catalog','James Sire','IVP',121
where not exists (select 1 from public.reading_books where title='The Universe Next Door: A Basic Worldview Catalog' and step=4 and category='Calling School');

NOTIFY pgrst, 'reload schema';
