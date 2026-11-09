//  📔 주간 기록 — 날짜가 붙은 데일리 기록 (개선창 ⑪ · 송희정 · 프로토스 · 11/06)
//
//    "시간표 일정을 바인더 기록하듯이 공동체 전체와 그룹별로 데일리 기록을
//     남기고 싶은데 날짜가 없네요. 11월 1주 2주 .. 한주씩 날짜와 함께
//     기록할수 있으면 좋겠어요"
//
//  재 보니 timetables 에는 day(요일)·period(교시) 만 있고 **날짜 칸이
//  없었습니다** — 지난주와 이번주를 가를 수가 없습니다. 그래서 수업표는
//  그대로 두고 날짜를 가진 표(weekly_logs) 를 옆에 뒀습니다.
//
//  ★ 여기서 재는 것
//   ① 날짜가 실제로 붙고, 주를 넘기면 그 주 것만 나온다
//   ② 공통 기록과 그룹 기록이 섞이지 않는다
//   ③ 간사 이상만 쓴다 (서버도 같은 선 — 운영 DB 에서 재서 확인했습니다)
//   ④ RLS 가 0줄을 돌려주면 저장했다고 거짓말하지 않는다
//   ⑤ 시간대가 달라도 날짜가 하루 밀리지 않는다
const { launch, openApp, ok, done } = require('./_harness');

//  2026-11-01 은 일요일 → 11/02 월 · 11/08 일 · 11/09 월 · 11/15 일
const MON2 = '2026-11-09';   // 11월 2주
const MON1 = '2026-11-02';   // 11월 1주

const LOGS = [
  { id:'L1', community_id:'c1', group_id:null,   log_date:'2026-11-09', content:'2주 월요일 — 공통', author_name:'김간사' },
  { id:'L2', community_id:'c1', group_id:null,   log_date:'2026-11-11', content:'2주 수요일 — 공통', author_name:'김간사' },
  { id:'L3', community_id:'c1', group_id:null,   log_date:'2026-11-03', content:'1주 화요일 — 공통', author_name:'김간사' },
  { id:'L4', community_id:'c1', group_id:'g1',   log_date:'2026-11-09', content:'2주 월요일 — 햇살반', author_name:'이교사' },
];

async function openLog(b, o = {}) {
  const pg = await openApp(b, Object.assign({ as:'teacher' }, o.tz ? { tz:o.tz } : {}));
  await pg.evaluate(async (d) => {
    ME.community_role = d.role || 'staff';
    ME.community_id = 'c1'; ME.name = '김간사';
    VIEW_CID = d.viewCid || null;
    tcsGroups = [{ id:'g1', name:'햇살반' }, { id:'g2', name:'달빛반' }];
    window.__DB.weekly_logs = d.LOGS.map(x => Object.assign({}, x));
    ttGroup = d.group || '';
    ttView = 'log';
    wlWeek = d.week || '';
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
    await loadWeeklyLogs();
    renderWeeklyLog();
  }, Object.assign({ LOGS }, o));
  return pg;
}
const READ = `() => {
  const el = document.getElementById('school-main');
  return {
    week: el.querySelector('[data-wl-week]').dataset.wlWeek,
    label: el.querySelector('[data-wl-week]').textContent.trim(),
    days: [...el.querySelectorAll('[data-wl-card]')].map(x => x.dataset.wlCard),
    dates: [...el.querySelectorAll('[data-wl-date]')].map(x => x.textContent.trim()),
    texts: [...el.querySelectorAll('textarea')].map(x => x.value),
    readonly: [...el.querySelectorAll('textarea')].every(x => x.hasAttribute('readonly')),
    save: !!el.querySelector('#wl-save'),
    by: [...el.querySelectorAll('[data-wl-by]')].map(x => x.textContent.trim()),
    //  ⚠️ 화면만 보면 안 된다. 화면은 날짜로 찾아 그리니 **걸러내기를 빼도
    //     똑같이 보인다** (되돌려 보고 ❌ 가 안 나와서 들켰다).
    //     그래서 '실제로 불러온 줄' 을 같이 잰다.
    loaded: (typeof wlRows === "undefined" ? [] : wlRows).map(r => r.id).sort().join(','),
  };
}`;

(async () => {
const b = await launch();

// ── ① 날짜가 붙는다 ────────────────────────────────────────
console.log('\n① 날짜가 붙는다 — 이게 없어서 올라온 요청입니다');
{
  const pg = await openLog(b, { week: MON2 });
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.days.length === 7, '월~일 7칸이 나온다 (' + r.days.length + '칸)');
  ok(r.days[0] === '2026-11-09' && r.days[6] === '2026-11-15',
     '첫 칸이 월요일, 끝 칸이 일요일 — 날짜 그대로');
  ok(r.dates[0] === '11/09' && r.dates[6] === '11/15', '칸마다 날짜가 적힌다');
  ok(/11월 2주/.test(r.label), "'11월 2주' 로 적힌다 ← 요청한 그대로");
  ok(/11\/09 ~ 11\/15/.test(r.label), '그 주의 날짜 범위도 같이 보인다');
}

// ── ② 주를 넘기면 그 주 것만 ──────────────────────────────
console.log('\n② 주를 넘기면 그 주 것만');
{
  const pg = await openLog(b, { week: MON2 });
  const r2 = await pg.evaluate(eval(READ));
  const r1 = await pg.evaluate(async () => {
    wlWeek = '2026-11-02'; await loadWeeklyLogs(); renderWeeklyLog();
    const el = document.getElementById('school-main');
    return { label: el.querySelector('[data-wl-week]').textContent.trim(),
             texts: [...el.querySelectorAll('textarea')].map(x => x.value),
             loaded: (typeof wlRows === "undefined" ? [] : wlRows).map(r => r.id).sort().join(',') };
  });
  await pg.close();
  ok(r2.texts[0] === '2주 월요일 — 공통' && r2.texts[2] === '2주 수요일 — 공통',
     '2주에는 2주 기록이 들어 있다');
  ok(!r2.texts.join('|').includes('1주 화요일'), '2주 화면에 1주 기록이 안 섞인다');
  ok(/11월 1주/.test(r1.label), '◀ 로 넘기면 11월 1주');
  ok(r1.texts[1] === '1주 화요일 — 공통', '지난 주 기록이 그대로 남아 있다');
  ok(!r1.texts.join('|').includes('2주 월요일'), '1주 화면에 2주 기록이 안 섞인다');
  //  ★ 여기가 핵심 — 화면이 아니라 '불러온 줄' 을 잰다
  ok(r2.loaded === 'L1,L2', '2주를 볼 때 그 주 것만 불러온다 (' + r2.loaded + ')');
  ok(r1.loaded === 'L3',    '1주를 볼 때 그 주 것만 불러온다 (' + r1.loaded + ')');
}

// ── ③ 공통 / 그룹이 갈려서 쌓인다 ─────────────────────────
console.log('\n③ 공통과 그룹이 갈린다');
{
  const pgA = await openLog(b, { week: MON2, group: '' });
  const a = await pgA.evaluate(eval(READ));
  await pgA.close();
  const pgB = await openLog(b, { week: MON2, group: 'g1' });
  const c = await pgB.evaluate(eval(READ));
  await pgB.close();
  ok(a.texts[0] === '2주 월요일 — 공통', '공통 보기에는 공통 기록');
  ok(!a.texts.join('|').includes('햇살반'), '공통 보기에 그룹 기록이 안 섞인다');
  ok(c.texts[0] === '2주 월요일 — 햇살반', '그룹 보기에는 그 그룹 기록');
  ok(!c.texts.join('|').includes('공통'), '그룹 보기에 공통 기록이 안 섞인다');
  ok(a.by.includes('김간사') && c.by.includes('이교사'), '누가 적었는지 보인다');
  ok(a.loaded === 'L1,L2', '공통 보기는 공통 줄만 불러온다 (' + a.loaded + ')');
  ok(c.loaded === 'L4',    '그룹 보기는 그 그룹 줄만 불러온다 (' + c.loaded + ')');
}

// ── ④ 누가 쓰나 ──────────────────────────────────────────
console.log('\n④ 누가 쓰나 — 간사 이상');
{
  for (const [role, viewCid, can, label] of [
    ['staff',           null, true,  '간사'],
    ['teacher',         null, true,  '교사'],
    ['community_admin', null, true,  '관리자'],
    ['admin_officer',   null, true,  '행정담당자'],
    ['super_admin',     null, true,  '총관리자'],
    ['vice_admin',      null, true,  '부총관리자 · 내 공동체'],
    ['vice_admin',      'c9', false, '부총관리자 · 남의 공동체 보는 중'],
    ['student',         null, false, '학생'],
    ['parent',          null, false, '학부모'],
  ]) {
    const pg = await openLog(b, { week: MON2, role, viewCid });
    const r = await pg.evaluate(eval(READ));
    await pg.close();
    ok(r.save === can && r.readonly === !can,
       `${label} — ${can ? '쓸 수 있다' : '읽기만 (서버도 막는다)'}`);
  }
}

// ── ⑤ 저장 ───────────────────────────────────────────────
console.log('\n⑤ 저장');
{
  const pg = await openLog(b, { week: MON2 });
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    document.getElementById('wl-2026-11-10').value = '새로 적은 화요일';   // 없던 날 → 넣기
    document.getElementById('wl-2026-11-09').value = '고친 월요일';         // 있던 날 → 고치기
    document.getElementById('wl-2026-11-11').value = '';                    // 비우면 → 지우기
    const beforeIns = window.__ins.length, beforeUpd = window.__upd.length;
    await saveWeeklyLog();
    return {
      said,
      ins: window.__ins.slice(beforeIns).map(x => ({ t:x.t, d:x.rows[0].log_date, c:x.rows[0].content, g:x.rows[0].group_id })),
      upd: window.__upd.slice(beforeUpd).map(x => ({ t:x.t, id:x.eq.id, c:x.u.content })),
      left: (window.__DB.weekly_logs || []).map(x => x.id).sort(),
      after: [...document.querySelectorAll('#school-main textarea')].map(x => x.value),
    };
  });
  await pg.close();
  ok(r.ins.length === 1 && r.ins[0].d === '2026-11-10' && r.ins[0].c === '새로 적은 화요일',
     '없던 날은 새로 넣는다 — 날짜를 그대로 보낸다');
  ok(r.ins[0].g === null, '공통 보기에서는 group_id 를 비워 보낸다');
  ok(r.upd.length === 1 && r.upd[0].id === 'L1' && r.upd[0].c === '고친 월요일',
     '있던 날은 고친다 — 바뀐 날만 보낸다 (3칸 중 1칸)');
  ok(!r.left.includes('L2'), '비운 날은 지운다');
  ok(r.left.includes('L3'), '다른 주 기록은 건드리지 않는다');
  ok(r.after[0] === '고친 월요일' && r.after[1] === '새로 적은 화요일' && r.after[2] === '',
     '화면도 바로 맞춰진다');
  ok(/저장했어요/.test(r.said) && /11월 2주/.test(r.said), '어느 주를 저장했는지 말해준다');
}
{
  //  안 건드리면 아무것도 안 보낸다
  const pg = await openLog(b, { week: MON2 });
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    const bi = window.__ins.length, bu = window.__upd.length;
    await saveWeeklyLog();
    return { said, ins: window.__ins.length - bi, upd: window.__upd.length - bu };
  });
  await pg.close();
  ok(r.ins === 0 && r.upd === 0, '안 건드린 날은 보내지 않는다');
  ok(/바뀐 게 없어요/.test(r.said), "'바뀐 게 없어요' 라고 말해준다");
}

// ── ⑥ 거짓말하지 않는다 ──────────────────────────────────
console.log('\n⑥ 거짓말하지 않는다');
{
  const pg = await openLog(b, { week: MON2 });
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    document.getElementById('wl-2026-11-10').value = '막힐 기록';
    //  RLS 가 막으면 error 없이 0줄이 온다 — 그 상황을 그대로 만든다
    const realFrom = sb.from;
    sb.from = (tbl) => {
      if (tbl !== 'weekly_logs') return realFrom(tbl);
      const q = realFrom(tbl);
      const realThen = q.then.bind(q);
      q.then = (res, rej) => (q._i || q._u || q._d)
        ? Promise.resolve({ data: q._i ? null : [], error: null }).then(res, rej)
        : realThen(res, rej);
      return q;
    };
    await saveWeeklyLog();
    sb.from = realFrom;
    return { said, left: (window.__DB.weekly_logs || []).map(x => x.id).sort() };
  });
  await pg.close();
  ok(/저장되지 않았어요/.test(r.said), '0줄이 오면 저장 안 됐다고 알려준다');
  ok(!/저장했어요/.test(r.said), "'저장했어요' 라고 거짓말하지 않는다");
}
{
  //  학생이 함수를 직접 불러도 아무것도 안 보낸다
  const pg = await openLog(b, { week: MON2, role:'student' });
  const r = await pg.evaluate(async () => {
    const bi = window.__ins.length, bu = window.__upd.length;
    await saveWeeklyLog();
    return { ins: window.__ins.length - bi, upd: window.__upd.length - bu };
  });
  await pg.close();
  ok(r.ins === 0 && r.upd === 0, '학생이 직접 불러도 아무것도 안 보낸다 ← 서버도 막는다');
}

// ── ⑦ 시간대가 달라도 날짜가 안 밀린다 ──────────────────
//  toISOString() 으로 날짜를 만들면 UTC 로 밀려서 **하루가 어긋납니다**.
//  UTC 컨테이너에서만 돌리면 그 버릇이 안 드러나니, 시간대를 옮겨서 잽니다.
console.log('\n⑦ 시간대 — 하루 밀리지 않는다');
{
  for (const [tz, when, want] of [
    ['Asia/Seoul',          [2026, 10, 9, 0, 30], '2026-11-09'],   // 한국 새벽 → UTC 로는 전날
    ['America/Los_Angeles', [2026, 10, 9, 23, 30], '2026-11-09'],  // 미국 밤 → UTC 로는 다음날
  ]) {
    const pg = await openLog(b, { week: MON2, tz });
    const r = await pg.evaluate((d) => {
      const dt = new Date(d.when[0], d.when[1], d.when[2], d.when[3], d.when[4]);
      return {
        mine: wlIso(dt),
        utc: dt.toISOString().slice(0, 10),
        offset: dt.getTimezoneOffset(),
        mon: wlMonday(new Date(2026, 10, 15)),      // 11/15 는 일요일 → 월요일은 11/09
        monFromMon: wlMonday(new Date(2026, 10, 9)),
        wkNo1: wlWeekNo('2026-11-02'), wkNo2: wlWeekNo('2026-11-09'),
      };
    }, { when });
    await pg.close();
    //  먼저 '덫이 걸려 있는지' 를 잰다 — UTC 와 같으면 이 시험은 아무것도 못 잡는다
    ok(r.utc !== want, `${tz} — 덫이 걸려 있다 (toISOString 은 ${r.utc} 로 어긋난다)`);
    ok(r.mine === want, `${tz} — 보는 사람 날짜 그대로 ${r.mine}`);
    ok(r.mon === '2026-11-09' && r.monFromMon === '2026-11-09',
       `${tz} — 일요일도 월요일도 그 주 월요일(11/09)로 모인다`);
    ok(r.wkNo1 === 1 && r.wkNo2 === 2, `${tz} — 11/02 는 1주, 11/09 는 2주`);
  }
}

await b.close();
done();
})();
