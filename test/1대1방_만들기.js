//  💬 1:1 방이 만들어지지 않던 것 (개선창 · 박유빈)
//
//  앱은 방을 만들면서 **방금 만든 줄을 돌려받습니다**
//  (.insert({...}).select().single()  =  insert ... returning).
//  읽기 정책이 my_channel_ids() 로만 보고 있었는데, 그 함수는 channels 표를
//  다시 읽습니다 — 같은 문장 안에서 방금 넣은 줄은 거기 안 보입니다.
//  그래서 학생이든 간사든 1:1 방을 못 만들었습니다 (단체방은 멀쩡).
//
//  여기서는 두 가지를 글로 못 박습니다.
//   ① 앱이 정말 'returning' 방식으로 만든다 — 그러니 정책이 그걸 견뎌야 한다
//   ② 정책의 맨 앞 조항이 **표를 다시 읽지 않는** created_by 비교다
const fs = require('fs'), path = require('path');
const { ok, done, ROOT } = require('./_harness');

const HTML = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const SQL  = fs.readFileSync(path.join(ROOT, 'db', '1대1방_만들기_복구.sql'), 'utf8')
               .replace(/--[^\n]*/g, '');          // 주석 글자에 속지 않는다

console.log('\n① 앱이 방을 만드는 방식');
//  kind:'dm' 으로 넣으면서 .select() 를 붙이는 자리
const dmCreate = HTML.match(/from\('channels'\)\.insert\(\{[^}]*kind:\s*'dm'[\s\S]{0,200}?\}\)\s*\.select\(\)/g) || [];
ok(dmCreate.length >= 1,
   "1:1 방을 insert(...).select() 로 만든다 — 즉 방금 만든 줄을 돌려받는다 (" + dmCreate.length + "군데)");

console.log('\n② 읽기 정책');
ok(/drop policy if exists channels_select/.test(SQL), 'channels_select 를 다시 만든다');

//  맨 앞 조항이 created_by 여야 한다. my_channel_ids() 가 먼저 오면
//  '표를 다시 읽는' 쪽으로 걸려 같은 자리에서 또 막힌다.
const using = SQL.slice(SQL.indexOf('using ('));
const iCreated = using.indexOf('created_by');
const iMyIds   = using.indexOf('my_channel_ids');
ok(iCreated > -1, '만든 사람 조항(created_by)이 있다');
ok(iMyIds > -1,   '내가 든 방 조항(my_channel_ids)도 그대로 있다');
ok(iCreated > -1 && iMyIds > -1 && iCreated < iMyIds,
   'created_by 가 맨 앞이다 — 표를 다시 읽지 않아야 RETURNING 에서 통과한다');
ok(/created_by = \(select auth\.uid\(\)\)/.test(SQL),
   'created_by 는 (select auth.uid()) 로 — 행마다 다시 부르지 않는다');

console.log('\n③ 넓어지지 않았나');
ok(/staff_of\(community_id\) and coalesce\(kind, 'topic'\) <> 'dm'/.test(SQL),
   "교직원이 보는 범위는 그대로 단체방만 (1:1 은 여전히 제외)");
ok(!/true\s*\)/.test(using.split('\n').slice(0,8).join('\n')),
   '아무나 다 보게 열어 둔 데가 없다');

console.log('\n④ 학생끼리는 여전히 막혀 있나 (막는 자리는 따로다)');
//  이 고침은 '방을 만든 사람이 그 줄을 본다' 만 건드린다. 누구와 1:1 을
//  틀 수 있나는 화면의 canDmMember 와 서버의 can_dm·channel_members 가
//  따로 지킨다. 그 자리가 지워지지 않았는지 본다.
ok(/isStudent\(\) && isStudentMember\(m\)\) return false/.test(HTML),
   '화면: 학생 × 학생 은 그대로 막는다');
ok(/isParentMember\(ME\) && !isStaffMember\(m\)\) return false/.test(HTML)
   && /isParentMember\(m\) && !isStaffMember\(ME\)\) return false/.test(HTML),
   '화면: 학부모가 낀 1:1 은 상대가 교직원일 때만 — 양쪽 다 본다');
ok(/m\.status === 'removed'\) return false/.test(HTML),
   '화면: 탈퇴한 사람과는 못 튼다');
ok(!/channel_members/.test(SQL),
   '이 SQL 은 channel_members 정책을 건드리지 않는다 — 상대를 넣는 자격은 그대로다');

done();
