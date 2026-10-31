//  📞 관리 → 전화 기록 — 달마다 전부 보이는가
//
//  예전에는 '공동체 설정' 한구석에 **최근 40통**만 붙어 있었습니다.
//  지난달 통화를 보려면 길이 없었습니다.
const { launch, openApp, ok, done } = require('./_harness.js');

//  달을 걸쳐 60통을 심는다 — 40개 벽이 없어졌는지 보려면 40보다 많아야 한다
function seedCalls() {
  const rows = [];
  const now = new Date();
  const mk = (d, who, to, status, sec) => {
    const start = d.toISOString();
    const ans = sec ? new Date(d.getTime() + 2000).toISOString() : null;
    const end = sec ? new Date(d.getTime() + 2000 + sec * 1000).toISOString() : null;
    rows.push({ id: 'c' + rows.length, community_id: 'c1', caller_id: who, callee_id: to,
                status, end_reason: null, created_at: start, answered_at: ans, ended_at: end });
  };
  for (let i = 0; i < 55; i++) {
    const d = new Date(now.getFullYear(), now.getMonth(), Math.max(1, 28 - (i % 27)), 10, i % 60);
    mk(d, i % 2 ? 'me' : 's1', i % 2 ? 's1' : 'me', i % 7 === 0 ? 'missed' : 'ended', i % 7 === 0 ? 0 : 60 + i);
  }
  //  '김하은' 이 낀 통화 두 통 — 이름으로 거르기를 보려고
  mk(new Date(now.getFullYear(), now.getMonth(), 2, 9, 0), 'me', 's2', 'ended', 30);
  mk(new Date(now.getFullYear(), now.getMonth(), 2, 9, 30), 's2', 'me', 'ended', 30);
  return rows;
}

(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'teacher' });
  await pg.evaluate((rows) => { window.__DB.calls = rows; }, seedCalls());

  // ── 탭이 있는가 ─────────────────────────────────────────────────
  await pg.evaluate(() => initAdminPage());
  await pg.waitForTimeout(400);
  const tabs = await pg.evaluate(() => ({
    calls: (document.getElementById('adm-tab-calls') || {}).style?.display,
    store: (document.getElementById('adm-tab-storage') || {}).style?.display,
    inPicker: admTabItems().map(x => x.key).join(','),
  }));
  ok(tabs.calls === 'block', '관리자에게 📞 전화 기록 메뉴가 보인다');
  ok(tabs.store === 'block', '관리자에게 💾 저장 용량 메뉴가 보인다');
  ok(/calls/.test(tabs.inPicker) && /storage/.test(tabs.inPicker), '휴대폰용 메뉴 고르개에도 들어 있다');

  // ── 40개 벽이 없어졌나 ──────────────────────────────────────────
  await pg.evaluate(() => switchAdminTab('calls'));
  await pg.waitForTimeout(500);
  const r1 = await pg.evaluate(() => ({
    rows: document.querySelectorAll('#cl-list .cl-row').length,
    sum: (document.getElementById('cl-sum') || {}).textContent || '',
    label: (document.querySelector('#admin-content [style*="min-width:140px"]') || {}).textContent || '',
    next: !!document.querySelector('.cl-nav[disabled]'),
  }));
  console.log('     합계 줄:', r1.sum.replace(/\s+/g, ' ').trim());
  ok(r1.rows === 57, '이 달 통화 57통을 다 보여 준다 (40통 벽이 없어졌다) — ' + r1.rows);
  ok(/모두/.test(r1.sum) && /57/.test(r1.sum), '모두 몇 통인지 적는다');
  ok(/통화된 것/.test(r1.sum) && /49/.test(r1.sum), '통화된 것만 따로 센다 (못 받은 건 빼고)');
  ok(/합계/.test(r1.sum) && /분/.test(r1.sum), '합계 시간을 적는다');
  ok(/못 받음/.test(r1.sum), '못 받은 것도 센다');
  ok(r1.next, '아직 안 온 달로는 못 넘어간다 (▶ 가 잠겨 있다)');

  // ── 달 넘기기 ───────────────────────────────────────────────────
  const thisLabel = r1.label.trim();
  await pg.evaluate(() => clShift(-1));
  await pg.waitForTimeout(400);
  const r2 = await pg.evaluate(() => ({
    label: (document.querySelector('#admin-content [style*="min-width:140px"]') || {}).textContent || '',
    back: !!document.querySelector('.cl-nav[disabled]'),
    hasNow: /이번 달/.test(document.getElementById('admin-content').innerHTML),
  }));
  ok(r2.label.trim() !== thisLabel && /월/.test(r2.label), '◀ 를 누르면 지난달로 간다 — ' + r2.label.trim());
  ok(!r2.back, '지난달에서는 ▶ 가 열린다');
  ok(r2.hasNow, "지난달에서는 '이번 달' 로 돌아올 단추가 생긴다");
  await pg.evaluate(() => clThisMonth());
  await pg.waitForTimeout(400);
  ok((await pg.evaluate(() => (document.querySelector('#admin-content [style*="min-width:140px"]') || {}).textContent || '')).trim() === thisLabel,
     '이번 달 단추로 돌아온다');

  // ── 이름으로 찾기 ───────────────────────────────────────────────
  await pg.evaluate(() => clSetFind('김하은'));
  await pg.waitForTimeout(250);
  const r3 = await pg.evaluate(() => ({
    rows: document.querySelectorAll('#cl-list .cl-row').length,
    txt: (document.getElementById('cl-list') || {}).textContent || '',
  }));
  ok(r3.rows === 2, '이름으로 걸러진다 (김하은 2통)');
  ok(/김하은/.test(r3.txt), '그 사람 줄만 남는다');
  await pg.evaluate(() => clSetFind('없는사람'));
  await pg.waitForTimeout(200);
  ok(/찾는 이름이 없어요/.test(await pg.evaluate(() => document.getElementById('cl-list').textContent)),
     '없는 이름을 치면 그렇게 말해 준다');
  await pg.evaluate(() => clSetFind(''));
  await pg.waitForTimeout(200);

  // ── 한 줄에 들어가는 것 ─────────────────────────────────────────
  const row = await pg.evaluate(() => (document.querySelector('#cl-list .cl-row') || {}).textContent || '');
  console.log('     한 줄:', row.replace(/\s+/g, ' ').trim());
  ok(/→/.test(row), '누가 누구에게 걸었는지 적는다');
  ok(/\d+\/\d+ \d+:\d+/.test(row), '언제인지 적는다');
  ok(/통화|못 받음/.test(row), '통화인지 못 받은 것인지 적는다');
  ok(/\d+:\d\d/.test(row), '몇 분 몇 초인지 적는다');

  // ── 아직 설치 안 했을 때 ────────────────────────────────────────
  await pg.evaluate(() => { window.__err = { table:'calls', e:{ message:'relation "public.calls" does not exist', code:'PGRST205' } }; });
  await pg.evaluate(() => switchAdminTab('calls'));
  await pg.waitForTimeout(400);
  const miss = await pg.evaluate(() => document.getElementById('cl-list').textContent);
  ok(/통화_DB설치\.sql/.test(miss), '설치 전이면 무엇을 돌려야 하는지 알려 준다');
  await pg.evaluate(() => { window.__err = null; });

  await pg.close(); await b.close(); done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
