//  🧾 db/저장용량_파일목록_DB설치.sql 을 읽어서 본다 — 두 번 데인 자리
//
//  이 파일의 함수들은 storage.objects 에 public.channels 를 붙입니다.
//  그래서 **파라미터 이름이 channels 의 칸 이름과 부딪히면**
//  'column reference ... is ambiguous' 로 목록이 통째로 안 나옵니다.
//  실제로 두 번 데었습니다 — 먼저 kind(= channels.kind), 그 다음
//  sort(= channels.sort). 브라우저도 데이터베이스도 없이, 글로 막습니다.
const fs = require('fs'), path = require('path');
const { ok, done } = require('./_harness.js');

const SQL = fs.readFileSync(path.join(__dirname, '..', 'db', '저장용량_파일목록_DB설치.sql'), 'utf8');

//  함수 하나의 '질의 부분' 만 떼어낸다 (return query … ;)
function bodyOf(name) {
  const i = SQL.indexOf('create or replace function public.' + name);
  if (i < 0) return null;
  const end = SQL.indexOf('end $$;', i);
  const rq = SQL.indexOf('return query', i);
  //  ⚠️ 주석은 빼고 본다. 주석에 'kind 를 맨 이름으로 쓰지 마라' 라고 적어
  //     두었는데, 그 글자 때문에 시험이 ❌ 를 냈다 (재 보고 알았다).
  return rq > 0 && rq < end
    ? SQL.slice(rq, end).replace(/--[^\n]*/g, '')
    : null;
}
//  선언부에서 파라미터 이름을 긁어온다
function paramsOf(name) {
  const i = SQL.indexOf('create or replace function public.' + name);
  const open = SQL.indexOf('(', i), close = SQL.indexOf(')', open);
  const head = SQL.slice(open + 1, close);
  return head.split(',').map(x => (x.trim().split(/\s+/)[0] || '')).filter(Boolean);
}

for (const fn of ['community_storage_files', 'community_storage_rooms']) {
  const body = bodyOf(fn);
  ok(!!body, fn + ' 의 질의 부분을 찾았다');
  if (!body) continue;
  const ps = paramsOf(fn);
  ok(ps.length > 0, fn + ' 의 파라미터를 찾았다 (' + ps.join(', ') + ')');
  for (const pname of ps) {
    //  '맨 이름' 으로 쓰인 데가 있나. fn.pname 으로 가린 것은 뺀다.
    const bare = new RegExp('(?<![.\\w"])' + pname + '(?![\\w"])', 'g');
    const hits = (body.replace(new RegExp(fn + '\\.' + pname, 'g'), '«»').match(bare) || []).length;
    ok(hits === 0, `${fn} — 파라미터 ${pname} 을 맨 이름으로 쓰지 않았다 (channels 의 칸과 부딪힌다)`);
  }
}

//  channels 의 칸 이름을 파라미터로 쓰고 있지는 않은가 — 쓰더라도 가렸으면 됨
const CH_COLS = ['id','name','kind','sort','description','emoji','group_id','pinned',
                 'community_id','created_by','last_message_at'];
const clash = paramsOf('community_storage_files').filter(p => CH_COLS.includes(p));
console.log('     channels 와 이름이 같은 파라미터:', clash.join(', ') || '없음');
ok(clash.length >= 1, 'kind·sort 처럼 부딪히는 이름이 실제로 있다 (그래서 이 시험이 있다)');

//  돌려주는 칸이 바뀌면 create or replace 는 거부만 하고 멈추지 않는다.
//  옛 몸통이 그대로 남은 채 설치가 끝나므로, 같은 이름은 먼저 지워야 한다.
ok(/drop function/.test(SQL) && /pg_proc/.test(SQL),
   '같은 이름의 옛 함수를 먼저 지운다 (안 그러면 옛 몸통이 남는다)');
ok(/proname in \('community_storage_rooms','community_storage_files'\)/.test(SQL),
   '두 함수를 모두 지운다');

//  지우기 정책 — 이게 없으면 화면에서 눌러도 오류 없이 0개가 돌아온다
ok(/create policy[\s\S]{0,120}on storage\.objects for delete/.test(SQL), '저장소에 지우기 정책을 단다');
ok(/can_delete_storage_file/.test(SQL), '지울 수 있는 사람인지 가린다');

//  보는 것도 아무나 하면 안 된다
for (const fn of ['community_storage_files', 'community_storage_rooms']) {
  const i = SQL.indexOf('create or replace function public.' + fn);
  const seg = SQL.slice(i, SQL.indexOf('end $$;', i));
  ok(/community_role in \('super_admin','vice_admin','community_admin'\)/.test(seg),
     fn + ' — 공동체를 맡은 사람만 볼 수 있다');
  ok(/can_view_all_communities/.test(seg), fn + ' — 남의 공동체는 총·부총관리자만');
}

done();
