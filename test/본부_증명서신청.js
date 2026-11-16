//  🏛️ 본부(IM HQ)에 증명서 신청하기
//
//    "다른 공동체가 IMHQ에 증명서 요청하는 섹션을 만들어줘
//     공동체들이 다 본부에 모여 수련회를 하는데 각 공동체에서 본부로
//     전국대회 수료증, 활동증명서 이런걸 신청하면 본부에서 승인해서
//     만들어주는 시스템으로 … 다 본부에서 일련번호로
//     신청할때 기본적으로 이름 생년월일 주소 소속공동체는 자동으로"
//
//  ★ 여기서 재는 것 — 화면을 실제로 그려서 읽습니다
//   ① 공동체에는 「본부에 신청」 탭이, 본부에는 「공동체에서 온 신청」 탭이
//   ② 본부가 정해져 있지 않으면 둘 다 안 보인다 (눌러도 아무 일 없으면 안 됨)
//   ③ 수료증·활동증명서는 공동체 발급 고르개에 없다
//      — 공동체가 직접 내면 번호가 공동체 줄로 나가 두 가지 번호가 생긴다
//   ④ 명단에서 체크해 신청하면 **고른 사람 수만큼** 올라가고,
//      이름·생년월일·주소·공동체이름이 자동으로 따라간다
//   ⑤ 대회 이름을 안 적으면 막힌다
//   ⑥ 본부 화면이 공동체별로 묶어 보여 준다
//   ⑦ 본부가 한꺼번에 발급하면 사람 수만큼 발급되고 신청이 닫힌다
//   ⑧ 신청함(우리 공동체 것)에 18개 공동체 신청이 섞이지 않는다
const { launch, openApp, ok, done } = require('./_harness');

const HQ = 'hq-1', C1 = 'c1';

//  공동체(프로토스) 쪽으로 화면을 세운다
async function asComm(b, o = {}) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((d) => {
    ME.community_id = 'c1'; ME.community_role = 'community_admin';
    members['m1'] = { id:'m1', name:'가나다', community_id:'c1', birth_date:'2010-03-15', address:'서울 어딘가', grade:'G7', status:'approved' };
    members['m2'] = { id:'m2', name:'라마바', community_id:'c1', birth_date:'2011-05-02', address:'경기 어딘가', grade:'G6', status:'approved' };
    members['m3'] = { id:'m3', name:'사아자', community_id:'c1', status:'approved' };   // 생년월일·주소 없음
    members['x9'] = { id:'x9', name:'남의공동체', community_id:'zzz', status:'approved' };
    window.__DB.communities = [
      { id:'hq-1', name:'IM HQ', is_hq: d.noHq ? false : true, cert_prefix:'IMHQ' },
      { id:'c1',   name:'프로토스', is_hq:false },
    ];
    window.__DB.cert_requests = (d.reqs || []).slice();
    window.__DB.record_orgs = [{ id:'o1', community_id:'c1', name:'프로토스', logo_url:'', address:'' }];
    window.__DB.org_seals = [];
    tcsOrgs = [{ id:'o1', name:'프로토스', logo_url:'', address:'' }];
    tcsSelectedOrgId = 'o1'; orgSeals = [];
    schoolStudents = [{ id:'m1', name:'가나다', grade:'G7', birth_date:'2010-03-15' }];
    certSubTab = d.tab || 'hq'; certReqFilter = 'pending';
    hqPicked = new Set(); hqInPicked = new Set(); hqQ = ''; hqEvent = ''; hqKind = 'natl_completion';
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
  }, o);
  await pg.evaluate(() => renderCertHub());
  await pg.waitForTimeout(150);
  return pg;
}

//  본부 쪽으로 화면을 세운다
async function asHq(b, reqs) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((rs) => {
    ME.community_id = 'hq-1'; ME.community_role = 'community_admin'; ME.id = 'hqme'; ME.name = '본부샘';
    window.__DB.communities = [
      { id:'hq-1', name:'IM HQ', is_hq:true, cert_prefix:'IMHQ' },
      { id:'c1',   name:'프로토스', is_hq:false },
    ];
    window.__DB.cert_requests = rs.slice();
    window.__DB.record_orgs = [{ id:'oh', community_id:'hq-1', name:'IM Korea', logo_url:'', address:'논산' }];
    tcsOrgs = [{ id:'oh', name:'IM Korea', logo_url:'', address:'논산' }];
    tcsSelectedOrgId = 'oh'; orgSeals = [];
    schoolStudents = [];
    certSubTab = 'hqin'; certReqFilter = 'pending';
    hqInPicked = new Set();
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
  }, reqs);
  await pg.evaluate(() => renderCertHub());
  await pg.waitForTimeout(150);
  return pg;
}

const REQ = (o) => Object.assign({
  id:'r1', community_id:'c1', community_name:'프로토스', to_community_id:'hq-1',
  batch_id:'b1', student_id:'m1', student_name:'가나다', student_birth:'2010-03-15',
  student_address:'서울 어딘가', requester_id:'me', requester_name:'김선생', relation:'staff',
  kind:'natl_completion', kind_label:'전국대회 수료증', event_name:'2026 전국대회',
  purpose:'대외 제출용', copies:1, status:'pending', created_at:'2026-11-10T00:00:00Z',
}, o);

//  ⚠️ 체크칸을 한 번 누르면 화면을 다시 그립니다. 누르기 전에 집어 둔
//     칸을 이어서 누르면 그 칸은 이미 떨어져 나간 것이라 아무 일도
//     안 일어납니다 (여기서 한 번 데었습니다). 사람이 하듯 누를 때마다
//     **다시 찾아서** 누릅니다.
const clickBox = (names) => (list) => {
  let n = 0;
  for (const want of list) {
    const lb = [...document.querySelectorAll('#school-main label')]
      .find(l => l.innerText.includes(want));
    const box = lb && lb.querySelector('input[type=checkbox]');
    if (box) { box.click(); n++; }
  }
  return n;
};

//  글자 문자열로 넘기면 playwright 가 함수로 안 보고 식으로 셈해서
//  undefined 가 돌아옵니다. 진짜 함수로 넘깁니다.
//
//  ⚠️ 화면 안의 버튼까지 다 긁으면 안 됩니다. 탭을 통째로 없애 보았을 때
//     시험이 통과해 버렸습니다 — 화면 안의 「본부에 신청**하기**」 버튼을
//     탭으로 잘못 집었기 때문입니다. **탭 줄만** 봅니다.
const TABS = () => [...document.querySelectorAll('#school-main button')]
  .filter(b => /setCertSubTab/.test(b.getAttribute('onclick') || ''))
  .map(b => b.textContent.trim()).filter(x => x);

(async () => {
const b = await launch();

// ── ① 탭 ────────────────────────────────────────────────────────
console.log('\n① 탭 — 공동체와 본부가 서로 다른 것을 본다');
{
  const pg = await asComm(b);
  const tabs = await pg.evaluate(TABS);
  ok(tabs.some(x => /본부에 신청/.test(x)), '공동체에는 「본부에 신청」 이 있다', tabs.join(' | '));
  ok(!tabs.some(x => /공동체에서 온 신청/.test(x)), '공동체에는 「공동체에서 온 신청」 이 없다');
  await pg.close();

  const pg2 = await asHq(b, [REQ({})]);
  const t2 = await pg2.evaluate(TABS);
  ok(t2.some(x => /공동체에서 온 신청/.test(x)), '본부에는 「공동체에서 온 신청」 이 있다', t2.join(' | '));
  ok(!t2.some(x => /본부에 신청/.test(x)), '본부에는 「본부에 신청」 이 없다 — 자기에게 신청하지 않는다');
  ok(t2.some(x => /공동체에서 온 신청\s*1/.test(x)), '기다리는 신청 수가 탭에 붙는다', t2.join(' | '));
  await pg2.close();
}

// ── ② 본부가 정해져 있지 않으면 ───────────────────────────────────
console.log('\n② 본부가 정해져 있지 않으면 — 누를 데를 만들지 않는다');
{
  const pg = await asComm(b, { noHq:true, tab:'issue' });
  const tabs = await pg.evaluate(TABS);
  ok(!tabs.some(x => /본부에 신청|공동체에서 온 신청/.test(x)), '두 탭 모두 안 보인다', tabs.join(' | '));
  await pg.close();
}

// ── ③ 공동체 발급 고르개 ─────────────────────────────────────────
console.log('\n③ 수료증·활동증명서는 본부만 낸다');
{
  const pg = await asComm(b, { tab:'issue' });
  const r = await pg.evaluate(() => {
    const sel = document.getElementById('cert-type');
    return sel ? [...sel.options].map(o => o.value) : null;
  });
  ok(!!r, '공동체 발급 화면이 그려졌다');
  ok(!r.includes('natl_completion'), '공동체 고르개에 전국대회 수료증이 없다', (r||[]).join(','));
  ok(!r.includes('activity_cert'), '공동체 고르개에 활동증명서가 없다', (r||[]).join(','));
  await pg.close();

  const pg2 = await asHq(b, []);
  const r2 = await pg2.evaluate(() => {
    certSubTab = 'issue';
    schoolStudents = [{ id:'s1', name:'본부아이' }];
    certStudentId = 's1'; certPrefill = { name:'본부아이', birth:'', school:'', address:'' };
    renderCert();
    const sel = document.getElementById('cert-type');
    return sel ? [...sel.options].map(o => o.value) : null;
  });
  ok(r2 && r2.includes('natl_completion') && r2.includes('activity_cert'),
     '본부 고르개에는 둘 다 있다', (r2||[]).join(','));
  await pg2.close();
}

// ── ④ 명단에서 체크해 신청 ───────────────────────────────────────
console.log('\n④ 명단에서 골라 신청 — 이름·생년월일·주소·공동체는 자동');
{
  const pg = await asComm(b);
  const r = await pg.evaluate(async () => {
    //  화면에 그려진 체크칸을 실제로 누른다
    const boxes = [...document.querySelectorAll('#school-main input[type=checkbox]')];
    //  누를 때마다 다시 찾는다
    ['가나다','라마바'].forEach(want => {
      const lb = [...document.querySelectorAll('#school-main label')].find(l => l.innerText.includes(want));
      const bx = lb && lb.querySelector('input[type=checkbox]');
      if (bx) bx.click();
    });
    hqEvent = '2026 전국대회';
    document.getElementById('hq-event').value = '2026 전국대회';
    await hqSend();
    await new Promise(r => setTimeout(r, 120));
    const call = (window.__rpc || []).filter(x => x.name === 'request_certs_to_hq').pop();
    return {
      boxes: boxes.length,
      names: document.getElementById('school-main').innerText,
      called: !!call,
      sent: call ? call.args.p : null,
      toast: document.body.innerText,
    };
  });
  ok(r.boxes >= 3 && !/남의공동체/.test(r.names || ''),
     '우리 공동체 사람만 명단에 뜬다 (남의 공동체 사람은 없다)', '체크칸 ' + r.boxes + '개');
  ok(r.called, '본부 신청 함수를 불렀다');
  ok(r.sent && r.sent.students && r.sent.students.length === 2, '고른 2명만 보냈다', JSON.stringify(r.sent && r.sent.students));
  ok(r.sent && r.sent.kind === 'natl_completion', '종류를 보냈다', r.sent && r.sent.kind);
  ok(r.sent && r.sent.event_name === '2026 전국대회', '대회 이름을 보냈다', r.sent && r.sent.event_name);
  await pg.close();
}

// ── ⑤ 대회 이름을 안 적으면 ──────────────────────────────────────
console.log('\n⑤ 대회 이름을 비우고 신청하면');
{
  const pg = await asComm(b);
  const r = await pg.evaluate(async () => {
    const lb0 = [...document.querySelectorAll('#school-main label')].find(l => l.innerText.includes('가나다'));
    lb0.querySelector('input[type=checkbox]').click();
    hqEvent = '';
    await hqSend();
    await new Promise(r => setTimeout(r, 80));
    return { called: (window.__rpc || []).some(x => x.name === 'request_certs_to_hq'),
             toast: document.body.innerText };
  });
  ok(!r.called, '조용히 보내지 않는다 — 막는다');
  ok(/대회 이름/.test(r.toast), '무엇을 적어야 하는지 알려준다');
  await pg.close();
}

// ── ⑥ 본부 화면 — 공동체별로 묶어 보기 ──────────────────────────
console.log('\n⑥ 본부 화면 — 한 번에 올라온 것끼리 묶어 보여준다');
{
  const pg = await asHq(b, [
    REQ({ id:'r1', student_id:'m1', student_name:'가나다' }),
    REQ({ id:'r2', student_id:'m2', student_name:'라마바', student_birth:'2011-05-02' }),
    REQ({ id:'r3', batch_id:'b2', community_id:'c1', community_name:'프로토스',
          kind:'activity_cert', kind_label:'활동증명서', event_name:'여름 사역', student_name:'사아자' }),
  ]);
  const r = await pg.evaluate(() => ({
    txt: document.getElementById('school-main').innerText,
    boxes: document.querySelectorAll('#school-main input[type=checkbox]').length,
  }));
  ok(/프로토스/.test(r.txt), '어느 공동체에서 왔는지 보인다');
  ok(/2026 전국대회/.test(r.txt) && /여름 사역/.test(r.txt), '대회 이름이 묶음마다 보인다');
  ok(/가나다/.test(r.txt) && /라마바/.test(r.txt) && /사아자/.test(r.txt), '사람 셋 다 보인다');
  ok(/2010-03-15/.test(r.txt), '생년월일이 신청에 실려 왔다 — 본부가 남의 공동체 자료를 안 읽는다');
  ok(r.boxes === 3, '체크칸이 사람마다 하나', r.boxes + '개');
  await pg.close();
}

// ── ⑦ 한꺼번에 발급 ─────────────────────────────────────────────
console.log('\n⑦ 본부가 한꺼번에 발급');
{
  const pg = await asHq(b, [
    REQ({ id:'r1', student_id:'m1', student_name:'가나다' }),
    REQ({ id:'r2', student_id:'m2', student_name:'라마바', student_birth:'2011-05-02' }),
  ]);
  const r = await pg.evaluate(async () => {
    //  서버가 번호를 매기는 자리를 흉내 낸다
    let n = 0;
    window.__DB['rpc:issue_certificate'] = [];
    const realOpen = window.open; window.open = () => ({
      document:{ write(){}, open(){}, close(){} }, close(){},
    });
    const sbr = sb.rpc.bind(sb);
    sb.rpc = (name, args) => {
      if (name === 'issue_certificate') {
        window.__rpc.push({ name, args });
        n++;
        return Promise.resolve({ data:{ id:'cert-'+n, cert_no:'IMHQ-2026-000'+n }, error:null });
      }
      return sbr(name, args);
    };
    ['가나다','라마바'].forEach(want => {
      const lb = [...document.querySelectorAll('#school-main label')].find(l => l.innerText.includes(want));
      const bx = lb && lb.querySelector('input[type=checkbox]');
      if (bx) bx.click();
    });
    //  ⚠️ 기간 칸은 **날짜 고르개(type=date)** 입니다. 달 고르개(month)는
    //     사파리·파이어폭스가 몰라서 달력이 안 뜨고 빈 칸으로 보입니다.
    document.getElementById('hq-pfrom').value = '2026-07-20';
    document.getElementById('hq-pto').value   = '2026-08-02';
    await hqIssuePicked();
    await new Promise(r => setTimeout(r, 200));
    window.open = realOpen;
    const calls = (window.__rpc || []).filter(x => x.name === 'issue_certificate');
    return {
      n: calls.length,
      first: calls[0] ? calls[0].args.p : null,
      reqs: (window.__DB.cert_requests || []).map(x => ({ id:x.id, st:x.status, no:x.cert_no })),
      toast: document.body.innerText,
    };
  });
  ok(r.n === 2, '고른 2명만큼 발급했다', r.n + '번 불렀다');
  ok(r.first && r.first.for_community_id === 'c1', '소속 공동체를 신청한 공동체로 찍는다', r.first && r.first.for_community_id);
  ok(r.first && r.first.for_community_name === '프로토스', '소속 공동체 이름도 함께', r.first && r.first.for_community_name);
  ok(r.first && /2026 전국대회/.test(r.first.statement || ''), '문장에 대회 이름이 들어간다', r.first && r.first.statement);
  ok(r.first && /2026년 7월 20일부터 8월 2일까지/.test(r.first.statement || ''), '문장에 기간이 날짜까지 들어간다', r.first && r.first.statement);
  ok(r.first && r.first.birth === '2010-03-15', '생년월일은 신청에 실린 값을 쓴다', r.first && r.first.birth);
  ok(r.reqs.every(x => x.st === 'issued'), '신청이 「발급 완료」 로 닫힌다', JSON.stringify(r.reqs));
  ok(r.reqs.every(x => /^IMHQ-2026-/.test(x.no || '')), '신청에 본부 번호가 적힌다', JSON.stringify(r.reqs.map(x=>x.no)));
  await pg.close();
}

// ── ⑦-2 기간을 비우고 발급하면 ───────────────────────────────────
console.log('\n⑦-2 기간을 비우고 발급하면');
{
  const pg = await asHq(b, [REQ({})]);
  const r = await pg.evaluate(async () => {
    //  ⚠️ 창을 못 열게 해 두면 그 자리에서 멈추는 바람에, 기간 검사를
    //     아예 없애도 시험이 통과합니다 (여기서 데었습니다). 창은 열리게
    //     해 두고 **기간 때문에 막히는지** 를 잽니다.
    const realOpen = window.open;
    window.open = () => ({ document:{ write(){}, open(){}, close(){} }, close(){} });
    const sbr = sb.rpc.bind(sb);
    sb.rpc = (name, args) => {
      if (name === 'issue_certificate') {
        window.__rpc.push({ name, args });
        return Promise.resolve({ data:{ id:'c1', cert_no:'IMHQ-2026-0001' }, error:null });
      }
      return sbr(name, args);
    };
    const lbA = [...document.querySelectorAll('#school-main label')].find(l => l.innerText.includes('가나다'));
    lbA.querySelector('input[type=checkbox]').click();
    await hqIssuePicked();
    await new Promise(r => setTimeout(r, 120));
    window.open = realOpen;
    return { called: (window.__rpc||[]).some(x => x.name === 'issue_certificate'),
             txt: document.body.innerText };
  });
  ok(!r.called, '기간이 없으면 발급하지 않는다');
  ok(/기간/.test(r.txt), '무엇이 빠졌는지 알려준다');
  await pg.close();
}

// ── ⑧ 신청함이 섞이지 않는다 ─────────────────────────────────────
console.log('\n⑧ 본부 「신청함」 에 18개 공동체 신청이 섞이면 안 된다');
{
  const pg = await asHq(b, [
    REQ({ id:'r1' }),                                              // 공동체 → 본부
    REQ({ id:'r9', community_id:'hq-1', community_name:'IM HQ',    // 본부 안의 학부모 신청
          to_community_id:null, batch_id:null, student_name:'본부아이', relation:'모' }),
  ]);
  const r = await pg.evaluate(() => {
    certSubTab = 'req'; renderCertRequests();
    const own = document.getElementById('school-main').innerText;
    certSubTab = 'hqin'; renderHqIn();
    const inb = document.getElementById('school-main').innerText;
    return { own, inb, nOwn: certReqsOwn().length, nIn: certReqsFromC().length, nToHq: certReqsToHq().length };
  });
  ok(r.nOwn === 1 && /본부아이/.test(r.own) && !/가나다/.test(r.own),
     '신청함에는 본부 안의 신청만 (1건)', '신청함 ' + r.nOwn + '건');
  ok(r.nIn === 1 && /가나다/.test(r.inb) && !/본부아이/.test(r.inb),
     '공동체에서 온 신청에는 공동체 것만 (1건)', '받은 것 ' + r.nIn + '건');
  ok(r.nToHq === 0, '본부는 본부에 보낸 것이 없다', r.nToHq + '건');
  await pg.close();
}

// ── ⑩ 기간 칸은 달력으로 고를 수 있어야 한다 ─────────────────────
//
//   사파리·파이어폭스는 달 고르개(type=month)를 **모릅니다.** 달력이
//   안 뜨고 그냥 빈 글자칸으로 보입니다 — 실제로 그렇게 보인다고
//   알려 주셨습니다(발급일자는 달력이 뜨는데 기간만 빈 칸이었습니다).
//   날짜 고르개(type=date)는 어디서나 달력이 뜹니다.
console.log('\n⑩ 기간 칸 — 어느 브라우저에서나 달력이 떠야 한다');
{
  const pg = await asHq(b, [REQ({})]);
  const r = await pg.evaluate(() => {
    const f = document.getElementById('hq-pfrom'), t2 = document.getElementById('hq-pto');
    const dt = document.getElementById('hq-date');
    return { from: f && f.type, to: t2 && t2.type, date: dt && dt.type };
  });
  ok(r.from === 'date', '기간(처음)이 날짜 고르개다 — month 는 사파리에서 빈 칸이 된다', r.from);
  ok(r.to === 'date', '기간(끝)도 날짜 고르개다', r.to);
  ok(r.date === 'date', '발급일자는 그대로 날짜 고르개', r.date);
  await pg.close();

  //  기부금 납입 증명서의 납입 기간도 같은 문제였다
  const pg2 = await asComm(b, { tab:'issue' });
  const r2 = await pg2.evaluate(() => {
    //  ⚠️ certSyncType() 은 고르개 값을 진짜로 봅니다 — 변수만 바꿔 놓고
    //     부르면 고르개 값으로 되돌립니다(화면이 먼저입니다). 사람이
    //     하듯 고르개에서 골라 줍니다.
    document.getElementById('cert-type').value = 'tuition_paid';
    certOnType('tuition_paid');
    const f = document.getElementById('cert-period-from'), t2 = document.getElementById('cert-period-to');
    return { from: f && f.type, to: t2 && t2.type, v: f && f.value, kind: certType };
  });
  ok(r2.from === 'date' && r2.to === 'date', '납입 기간도 날짜 고르개다', r2.from + '/' + r2.to);
  ok(r2.kind === 'tuition_paid', '기부금 납입 증명서를 골랐다', r2.kind);
  ok(/^\d{4}-\d{2}-\d{2}$/.test(r2.v || ''), '처음 띄울 때 넣어 주는 값도 날짜 꼴이다', JSON.stringify(r2));
  await pg2.close();
}

// ── ⑪ 기간 글 — 날짜까지, 옛 기록(달만)도 그대로 ────────────────
console.log('\n⑪ 증서에 찍히는 기간 글');
{
  const pg = await asHq(b, []);
  const r = await pg.evaluate(() => ({
    day:   certPeriodText('2026-07-20','2026-08-02','ko'),
    same:  certPeriodText('2026-07-20','2026-07-20','ko'),
    yr:    certPeriodText('2025-12-20','2026-01-05','ko'),
    month: certPeriodText('2026-03','2026-08','ko'),          // 옛 기록
    en:    certPeriodText('2026-07-20','2026-08-02','en'),
  }));
  ok(r.day === '2026년 7월 20일부터 8월 2일까지', '날짜 두 개면 날짜까지 쓴다', r.day);
  ok(r.same === '2026년 7월 20일', '같은 날이면 하루만 쓴다', r.same);
  ok(/2025년 12월 20일부터 2026년 1월 5일까지/.test(r.yr), '해를 넘기면 두 해를 다 쓴다', r.yr);
  ok(r.month === '2026년 3월부터 8월까지', '달까지만 적힌 옛 기록은 그대로 읽는다', r.month);
  ok(/July 20 to August 2, 2026/.test(r.en), '영문도 날짜까지', r.en);
  await pg.close();
}

// ── ⑫ 신청한 공동체가 발급된 증서를 직접 뽑는다 ─────────────────
//
//   본부가 승인하면 그 증서는 본부 대장에 남습니다. 공동체가 못 뽑으면
//   "발급됐다" 는 글자만 보고 본부에 다시 달라고 해야 합니다.
console.log('\n⑫ 신청한 공동체가 📄 인쇄 · PDF 로 뽑는다');
{
  const pg = await asComm(b, {
    reqs: [
      REQ({ id:'r-ok', status:'issued', cert_no:'IMHQ-2026-0007', certificate_id:'cert-7' }),
      REQ({ id:'r-wait', status:'pending' }),
    ],
  });
  const r = await pg.evaluate(() => {
    const txt = document.getElementById('school-main').innerText;
    const btns = [...document.querySelectorAll('#school-main button')]
      .filter(x => /hqPrintIssued/.test(x.getAttribute('onclick') || ''));
    return { txt, n: btns.length, on: btns.map(x => x.getAttribute('onclick')) };
  });
  ok(/IMHQ-2026-0007/.test(r.txt), '본부가 매긴 번호가 공동체에도 보인다');
  ok(r.n === 1, '발급된 것에만 인쇄 단추가 붙는다 (기다리는 것엔 없다)', r.n + '개');
  ok(/cert-7/.test((r.on || [])[0] || ''), '그 증서를 가리킨다', (r.on||[])[0]);

  //  실제로 눌러서 본부 대장의 증서를 뽑아 본다
  const out = await pg.evaluate(async () => {
    window.__printed = [];
    window.open = () => ({ document:{ open(){}, close(){}, write(h){ window.__printed.push(String(h)); } }, close(){} });
    window.__DB.certificates = [{
      id:'cert-7', community_id:'hq-1', for_community_id:'c1', for_community_name:'프로토스',
      cert_no:'IMHQ-2026-0007', lang:'ko', type:'natl_completion', doc_label:'수 료 증',
      student_name:'가나다', birth:'2010-03-15', statement:'위 사람은 … 수료하였음을 확인합니다.',
      issue_date:'2026-11-16', org_name:'IM Korea', org_address:'충남 논산시 벌곡면 황룡재로 324',
      rep:'IM Korea 장', seal_url:'', event_name:'2026 전국대회', form_snap:null,
    }];
    await hqPrintIssued('cert-7');
    await new Promise(r => setTimeout(r, 150));
    return { html: (window.__printed || []).join('\n') };
  });
  ok(/수 료 증/.test(out.html), '본부가 만든 증서가 그대로 나온다', out.html.slice(0,0));
  ok(/IMHQ-2026-0007/.test(out.html), '본부 번호가 찍혀 있다');
  ok(/가나다/.test(out.html), '이름이 찍혀 있다');
  ok(/IM Korea/.test(out.html), '본부 기관명으로 나간다 — 공동체 이름이 아니다');
  await pg.close();
}

done(b);
})();
