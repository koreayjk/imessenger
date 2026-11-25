//  💬 상담기록 — 「상담한 선생님」 고르는 칸
//
//  개선창 · Clara (IM HQ, 11/13):
//    「[학사] >> [상담기록]에 추가했으면 하는게 있습니다 !!
//      상담을 어느 선생님이 했는지 선택하는 란이 있으면 좋겠습니다.
//      선생님 이름이 다 나와서 누가 했는지를 클릭하게요 !」
//
//  ⚠️ 적은 사람(author_name) 을 상담한 사람으로 쓰면 안 됩니다. 간사가
//     선생님 상담을 대신 적어 넣는 일이 있습니다. 칸을 따로 둡니다
//     (counselor_id · counselor_name — db/학사_상담_상담한선생님_DB설치.sql).
//
//  재는 것:
//   ① 상담기록에만 그 칸이 있다 (관찰·보건에는 없다)
//   ② 선생님 이름이 다 나오고, 처음엔 내가 골라져 있다
//   ③ 고른 선생님이 id·이름 둘 다 저장된다
//   ④ 적은 사람은 그대로 나로 남는다
//   ⑤ 목록에 상담한 선생님이 보이고, 적은이가 다르면 그것도 보인다
//   ⑥ SQL 을 안 돌린 공동체에서도 기록 자체는 들어간다
const { launch, openApp, ok, done } = require('./_harness');

const STUDENTS = [{ id:'st1', name:'홍길동', grade:'G7' }];
const TEACHERS = [
  { id:'me',  name:'김간사' },
  { id:'t2',  name:'이선생' },
  { id:'t3',  name:'박선생' },
];

async function openLog(b, key) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(async ([ss, ts, k]) => {
    ME.id = 'me'; ME.name = '김간사';
    schoolStudents = JSON.parse(JSON.stringify(ss));
    schoolTeachers = JSON.parse(JSON.stringify(ts));
    logStudentId = 'st1';
    window.__DB['counseling_logs'] = [];
    window.__DB['observation_logs'] = [];
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
    await renderLogHub(k);
  }, [STUDENTS, TEACHERS, key]);
  await pg.waitForTimeout(400);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 상담기록에만 ─────────────────────────────────────────
console.log('\n① 어느 기록에 붙었나');
{
  const pg = await openLog(b, 'counseling');
  const a = await pg.evaluate(() => !!document.getElementById('log-who'));
  await pg.evaluate(async () => { await renderLogHub('observation'); });
  await pg.waitForTimeout(300);
  const c = await pg.evaluate(() => !!document.getElementById('log-who'));
  await pg.evaluate(async () => { await renderLogHub('health'); });
  await pg.waitForTimeout(300);
  const h = await pg.evaluate(() => !!document.getElementById('log-who'));
  ok(a,  '상담기록에는 「상담한 선생님」 칸이 있다');
  ok(!c, '관찰 누가기록에는 없다 (요청은 상담이었다)');
  ok(!h, '보건기록에도 없다');
  await pg.close();
}

// ── ② 선생님 목록 ──────────────────────────────────────────
console.log('\n② 고를 수 있는 선생님');
{
  const pg = await openLog(b, 'counseling');
  const r = await pg.evaluate(() => {
    const sel = document.getElementById('log-who');
    return { opts: [...sel.options].map(o => o.text),
             vals: [...sel.options].map(o => o.value),
             picked: sel.value };
  });
  ok(r.opts.length === 3, '선생님 세 분이 다 나온다', r.opts.join(' / '));
  ok(/김간사/.test(r.opts[0]) && /\(나\)/.test(r.opts[0]), '내가 맨 앞이고 (나) 라고 적힌다', r.opts[0]);
  ok(r.opts.join('|').includes('이선생') && r.opts.join('|').includes('박선생'),
     '다른 선생님 이름도 나온다', r.opts.join(' / '));
  ok(r.vals.filter(v => v === 'me').length === 1, '내 이름이 두 번 나오지 않는다', r.vals.join(','));
  ok(r.picked === 'me', '처음엔 내가 골라져 있다', r.picked);
  await pg.close();
}

// ── ③④ 고른 선생님이 저장된다 ──────────────────────────────
console.log('\n③ 다른 선생님을 골라 저장');
{
  const pg = await openLog(b, 'counseling');
  const r = await pg.evaluate(async () => {
    document.getElementById('log-who').value = 't2';     // 이선생이 상담했다
    document.getElementById('log-title').value = '진로 상담';
    document.getElementById('log-content').value = '대학 이야기';
    await addLog();
    await new Promise(r => setTimeout(r, 400));
    const ins = (window.__ins || []).filter(x => x.t === 'counseling_logs');
    return { row: ins.length ? ins[0].rows[0] : null, toast: window.__toast.join('|') };
  });
  ok(r.row && r.row.counselor_id === 't2',   '고른 선생님의 id 가 저장된다', r.row && r.row.counselor_id);
  ok(r.row && r.row.counselor_name === '이선생', '이름도 저장된다 (나중에 이름이 바뀌어도 남게)', r.row && r.row.counselor_name);
  ok(r.row && r.row.author_name === '김간사', '적은 사람은 그대로 나다', r.row && r.row.author_name);
  ok(r.row && r.row.created_by === 'me',     'created_by 도 나다', r.row && r.row.created_by);
  ok(!/저장되지 않아요/.test(r.toast),        '칸이 있으니 안내가 뜨지 않는다', r.toast);
  await pg.close();
}

// ── ③-2 나를 고르면 (나) 가 이름에 안 붙는다 ────────────────
console.log('\n③-2 나를 골랐을 때');
{
  const pg = await openLog(b, 'counseling');
  const r = await pg.evaluate(async () => {
    document.getElementById('log-title').value = '내가 한 상담';
    await addLog();
    await new Promise(r => setTimeout(r, 400));
    const ins = (window.__ins || []).filter(x => x.t === 'counseling_logs');
    return ins.length ? ins[0].rows[0] : null;
  });
  ok(r && r.counselor_name === '김간사', "이름에 '(나)' 가 묻어 들어가지 않는다", r && r.counselor_name);
  await pg.close();
}

// ── ⑤ 목록에 보이나 ────────────────────────────────────────
console.log('\n⑤ 목록에 적히는 모양');
{
  const pg = await openLog(b, 'counseling');
  const r = await pg.evaluate(async () => {
    logEntries = [
      { id:'a', date:'2026-11-13', category:'상담', title:'진로', content:'내용',
        author_name:'김간사', counselor_name:'이선생' },
      { id:'b', date:'2026-11-12', category:'상담', title:'같은사람', content:'내용',
        author_name:'김간사', counselor_name:'김간사' },
      { id:'c', date:'2026-11-11', category:'상담', title:'옛기록', content:'내용',
        author_name:'김간사' },
    ];
    renderLog();
    const txt = document.getElementById('school-main').innerText;
    return { txt };
  });
  ok(/이선생/.test(r.txt),                  '상담한 선생님이 보인다');
  ok(/적은이 김간사/.test(r.txt),            '적은이가 다르면 그것도 적는다');
  ok((r.txt.match(/적은이/g) || []).length === 1,
     '같은 사람이면 「적은이」 를 두 번 안 적는다', (r.txt.match(/적은이/g)||[]).length);
  ok(/옛기록/.test(r.txt),                  '칸이 비어 있는 옛 기록도 그대로 보인다');
  await pg.close();
}

// ── ⑥ SQL 을 안 돌렸을 때 ──────────────────────────────────
console.log('\n⑥ 칸이 아직 없는 공동체');
{
  const pg = await openLog(b, 'counseling');
  const r = await pg.evaluate(async () => {
    const real = sb.from;
    let tries = 0;
    sb.from = (tb) => tb === 'counseling_logs' ? {
      insert: (row) => {
        tries++;
        if ('counselor_name' in row)
          return Promise.resolve({ error: { message: `column "counselor_name" of relation "counseling_logs" does not exist` } });
        window.__fallbackRow = row;
        return Promise.resolve({ error: null });
      },
      select: () => ({ eq: () => ({ eq: () => ({ order: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }) }) }),
    } : real(tb);
    window.__toast = [];
    document.getElementById('log-title').value = '칸 없어도';
    await addLog();
    await new Promise(r => setTimeout(r, 400));
    sb.from = real;
    return { tries, row: window.__fallbackRow, toast: window.__toast.join('|') };
  });
  ok(r.tries === 2,                    '한 번 막히면 그 칸만 빼고 다시 넣는다', r.tries);
  ok(r.row && r.row.title === '칸 없어도', '기록 자체는 들어간다', r.row && r.row.title);
  ok(r.row && !('counselor_name' in r.row), '두 번째에는 그 칸이 빠져 있다', JSON.stringify(r.row));
  ok(/저장되지 않아요/.test(r.toast) && /DB설치\.sql/.test(r.toast),
     '어떤 SQL 을 돌려야 하는지 알려 준다', r.toast);
  await pg.close();
}

await b.close();
done();
})();
