//  🖼 공동체마다 자기 증명서 양식
//
//    "증명서 양식을 동일하게 안 가고 각 공동체에서 만든 양식을 사용하게
//     할건데, 기존 양식을 pdf로 한번 올리면 그대로 내용과 이름 이런것들만
//     바꿔서 사용할수 있게. 각 공동체마다 다르게, 없으면 기존거 쓰고"
//
//  ⚠️ PDF 안의 글자는 못 바꿉니다(스캔은 글자가 아니라 그림, 글자 PDF도
//     다시 쓰려면 한글 글꼴을 심어야 하고 줄이 어긋납니다). 그래서
//     **양식을 배경으로 깔고 글자를 그 위에 얹습니다.**
//
//  ★ 여기서 재는 것
//   ① 양식이 없으면 기본 증서가 나간다 (지금 쓰던 그대로)
//   ② 양식이 있으면 그 양식으로 나간다 — 배경 그림과 값이 함께
//   ③ 종류별 양식이 공용 양식을 이긴다 (수료증 양식 > 모든 종류 공용)
//   ④ 자리는 비율(%)로 찍힌다 — 화면 크기가 바뀌어도 안 어긋난다
//   ⑤ 꺼 둔 자리와 값이 빈 자리는 아예 안 찍힌다
//   ⑥ 발급할 때 form_id 를 보낸다 (서버가 그때 양식을 떠 둔다)
//   ⑦ 다시 뽑을 때는 **그때 쓴 양식**으로 나온다 (양식을 고친 뒤에도)
//   ⑧ 편집 화면에서 꼬리표를 끌면 자리가 바뀌고, 저장 전까지 서버로 안 간다
//   ⑨ 한 종류에 양식 둘은 못 올린다
const { launch, openApp, ok, done } = require('./_harness');

const BG = 'about:blank#form.png';
const FORM = (o) => Object.assign({
  id:'f1', community_id:'c1', name:'우리 수료증 양식', kind:null,
  bg_url: BG, bg_w:1240, bg_h:1754, landscape:false, enabled:true,
  fields:[
    { k:'name', x:0.5,  y:0.34, w:0.5, align:'center', size:19, bold:true, on:true },
    { k:'stmt', x:0.5,  y:0.60, w:0.78, align:'center', size:15, line:1.9, on:true },
    { k:'no',   x:0.16, y:0.085, w:0.3, align:'left',  size:11, on:true },
    { k:'seal', x:0.72, y:0.89, w:0.11, on:true },
    { k:'grade', x:0.5, y:0.44, w:0.4, align:'center', size:14, on:false },  // 꺼 둔 자리
    { k:'address', x:0.5, y:0.5, w:0.7, align:'center', size:13, on:true },  // 값이 빌 것
  ],
}, o);

async function open1(b, forms) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((fs) => {
    ME.community_id = 'c1'; ME.community_role = 'community_admin'; ME.id = 'me'; ME.name = '김선생';
    COMM_NAME = '프로토스';
    window.__DB.communities = [{ id:'c1', name:'프로토스', is_hq:false }];
    window.__DB.cert_forms = fs.slice();
    window.__DB.cert_requests = []; window.__DB.certificates = [];
    window.__DB.record_orgs = [{ id:'o1', community_id:'c1', name:'프로토스', logo_url:'', address:'천안' }];
    tcsOrgs = [{ id:'o1', name:'프로토스', logo_url:'', address:'천안' }];
    tcsSelectedOrgId = 'o1';
    //  ⚠️ renderCertHub() 가 loadOrgSeals() 로 DB 에서 다시 읽습니다.
    //     변수에만 심어 두면 지워집니다 — DB 에 심습니다.
    window.__DB.org_seals = [{ id:'s1', community_id:'c1', name:'대표자 직인', image_url:'about:blank#seal.png' }];
    orgSeals = window.__DB.org_seals.slice();
    schoolStudents = [{ id:'m1', name:'가나다', grade:'G7', birth_date:'2010-03-15' }];
    certStudentId = 'm1';
    certPrefill = { name:'가나다', birth:'2010-03-15', school:'', address:'' };
    certSubTab = 'issue'; certLang = 'ko'; certType = 'admit';
    cfEditId = null; cfPickK = null; cfDirty = false;
    //  ⚠️ #school-main 은 이미 #school-view 안에 있는데, 그 뷰는
    //     display:none 입니다. 숨은 채로 그려 놓고 끌면 자리가 0×0 이라
    //     아무 일도 안 일어납니다 (여기서 한 번 데었습니다).
    //     쓰는 분이 그 화면에 들어간 상태를 그대로 만들어 둡니다.
    const sv = document.getElementById('school-view');
    if (sv) sv.style.display = 'flex';
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
    window.__FORM_FIELDS = (fs[0] && fs[0].fields) ? JSON.parse(JSON.stringify(fs[0].fields)) : [];
  }, forms);
  await pg.evaluate(() => renderCertHub());
  await pg.waitForTimeout(150);
  return pg;
}

//  발급을 눌렀을 때 인쇄창에 들어간 글을 가로챈다


(async () => {
const b = await launch();

// ── ① 양식이 없으면 기본 증서 ────────────────────────────────────
console.log('\n① 양식을 안 올린 공동체 — 지금 쓰던 기본 증서가 나간다');
{
  const pg = await open1(b, []);
  const r = await pg.evaluate(async () => {
    window.__printed = [];
  window.open = () => ({
    document: { open(){}, close(){}, write(h){ window.__printed.push(String(h)); } },
    close(){},
  });
  const sbr = sb.rpc.bind(sb);
  window.__issued = [];
  sb.rpc = (name, args) => {
    if (name === 'issue_certificate') {
      window.__issued.push(args.p);
      //  서버가 하는 일을 흉내 낸다: form_id 를 받아 그때 양식을 떠 준다
      const f = (window.__DB.cert_forms || []).find(x => x.id === args.p.form_id) || null;
      return Promise.resolve({ data: {
        id:'cert-1', cert_no:'2026-0001',
        form_id: f ? f.id : null,
        form_snap: f ? { id:f.id, name:f.name, kind:f.kind, bg_url:f.bg_url,
                         bg_w:f.bg_w, bg_h:f.bg_h, landscape:f.landscape, fields:f.fields } : null,
      }, error:null });
    }
    return sbr(name, args);
  };
    await printCertificate();
    await new Promise(r => setTimeout(r, 200));
    return { html: (window.__printed || []).join('\n'), sent: window.__issued[0] || null,
             note: (document.getElementById('cert-form-note') || {}).innerText || '' };
  });
  ok(/class="cf"/.test(r.html), '기본 증서(테두리 있는 것)로 나간다');
  ok(!/class="cfm"/.test(r.html), '양식 배경을 깔지 않는다');
  ok(r.sent && !r.sent.form_id, '발급할 때 양식을 안 보낸다', JSON.stringify(r.sent && r.sent.form_id));
  ok(/기본 증서/.test(r.note), '발급 화면이 「기본 증서로 나갑니다」 라고 알려 준다', r.note);
  await pg.close();
}

// ── ② 양식이 있으면 그 양식으로 ──────────────────────────────────
console.log('\n② 양식을 올린 공동체 — 그 양식으로 나간다');
{
  const pg = await open1(b, [FORM({})]);
  const r = await pg.evaluate(async () => {
    //  직인은 고르개에서 골라야 찍힌다 (기본은 「직인 없음」 이 맞다)
    document.getElementById('cert-seal').value = 's1';
    window.__printed = [];
  window.open = () => ({
    document: { open(){}, close(){}, write(h){ window.__printed.push(String(h)); } },
    close(){},
  });
  const sbr = sb.rpc.bind(sb);
  window.__issued = [];
  sb.rpc = (name, args) => {
    if (name === 'issue_certificate') {
      window.__issued.push(args.p);
      //  서버가 하는 일을 흉내 낸다: form_id 를 받아 그때 양식을 떠 준다
      const f = (window.__DB.cert_forms || []).find(x => x.id === args.p.form_id) || null;
      return Promise.resolve({ data: {
        id:'cert-1', cert_no:'2026-0001',
        form_id: f ? f.id : null,
        form_snap: f ? { id:f.id, name:f.name, kind:f.kind, bg_url:f.bg_url,
                         bg_w:f.bg_w, bg_h:f.bg_h, landscape:f.landscape, fields:f.fields } : null,
      }, error:null });
    }
    return sbr(name, args);
  };
    await printCertificate();
    await new Promise(r => setTimeout(r, 200));
    return { html: (window.__printed || []).join('\n'), sent: window.__issued[0] || null,
             note: (document.getElementById('cert-form-note') || {}).innerText || '' };
  });
  ok(/class="cfm"/.test(r.html), '양식 배경을 깐 증서로 나간다');
  ok(!/class="cf"[^m]/.test(r.html), '기본 증서는 안 나간다');
  ok(r.html.includes('form.png'), '배경 그림이 들어 있다');
  ok(/가나다/.test(r.html), '이름이 얹혀 있다');
  ok(/2026-0001/.test(r.html), '발급번호가 얹혀 있다');
  ok(/seal\.png/.test(r.html), '직인 그림이 얹혀 있다');
  ok(/우리 수료증 양식/.test(r.note), '어떤 양식으로 나가는지 알려 준다', r.note);
  await pg.close();
}

// ── ③ 종류별 양식이 공용을 이긴다 ────────────────────────────────
console.log('\n③ 종류별 양식 > 모든 종류 공용');
{
  const pg = await open1(b, [
    FORM({ id:'f-all',  name:'공용 양식',   kind:null }),
    FORM({ id:'f-ad',   name:'입소증명 양식', kind:'admit' }),
  ]);
  const r = await pg.evaluate(() => ({
    forAdmit: (certFormFor('admit') || {}).name,
    forOther: (certFormFor('tuition_paid') || {}).name,
    forNone:  (certFormFor('없는종류') || {}).name,
  }));
  ok(r.forAdmit === '입소증명 양식', '입소증명서는 종류별 양식을 쓴다', r.forAdmit);
  ok(r.forOther === '공용 양식', '양식이 없는 종류는 공용을 쓴다', r.forOther);
  await pg.close();

  const pg2 = await open1(b, [FORM({ id:'f-ad', name:'입소증명 양식', kind:'admit' })]);
  const r2 = await pg2.evaluate(() => ({
    forAdmit: (certFormFor('admit') || {}).name,
    forOther: certFormFor('tuition_paid'),
  }));
  ok(r2.forAdmit === '입소증명 양식', '종류별 양식만 있으면 그 종류에만 쓴다');
  ok(r2.forOther === null, '다른 종류는 양식 없음 → 기본 증서', String(r2.forOther));
  await pg2.close();
}

// ── ④⑤ 자리는 %, 꺼 둔 것과 빈 것은 안 찍힌다 ───────────────────
console.log('\n④⑤ 자리는 비율(%)로 · 꺼 둔 자리와 빈 값은 안 찍힌다');
{
  const pg = await open1(b, [FORM({})]);
  const r = await pg.evaluate(() => {
    const f = window.__DB.cert_forms[0];
    const body = buildCertFormBody({
      lang:'ko', name:'가나다', stmt:'위 사람은 …', no:'2026-0001',
      sealUrl:'about:blank#seal.png', grade:'G7', address:'',
    }, f);
    return { body };
  });
  ok(/left:50\.000%/.test(r.body), '가로 자리가 % 로 찍힌다 (픽셀 아님)');
  ok(/top:34\.000%/.test(r.body), '세로 자리도 % 로');
  ok(/left:16\.000%/.test(r.body) && !/right:/.test(r.body.split('16.000')[1].slice(0,60)),
     '왼쪽 맞춤은 x 가 왼쪽 끝이다');
  ok(!/G7/.test(r.body), '꺼 둔 자리(학년)는 값이 있어도 안 찍힌다');
  ok(!/address/.test(r.body) || !/주소/.test(r.body), '값이 빈 자리(주소)는 아예 안 찍힌다');
  ok(/aspect-ratio:1240\/1754/.test(r.body), '양식 그림의 비율을 지킨다 — 찌그러지지 않는다');
  await pg.close();
}

// ── ⑥⑦ 발급할 때 form_id · 다시 뽑을 때 그때 양식 ───────────────
console.log('\n⑥⑦ 발급할 때 양식을 알려주고, 다시 뽑을 때는 그때 양식으로');
{
  const pg = await open1(b, [FORM({})]);
  const r = await pg.evaluate(async () => {
    window.__printed = [];
  window.open = () => ({
    document: { open(){}, close(){}, write(h){ window.__printed.push(String(h)); } },
    close(){},
  });
  const sbr = sb.rpc.bind(sb);
  window.__issued = [];
  sb.rpc = (name, args) => {
    if (name === 'issue_certificate') {
      window.__issued.push(args.p);
      //  서버가 하는 일을 흉내 낸다: form_id 를 받아 그때 양식을 떠 준다
      const f = (window.__DB.cert_forms || []).find(x => x.id === args.p.form_id) || null;
      return Promise.resolve({ data: {
        id:'cert-1', cert_no:'2026-0001',
        form_id: f ? f.id : null,
        form_snap: f ? { id:f.id, name:f.name, kind:f.kind, bg_url:f.bg_url,
                         bg_w:f.bg_w, bg_h:f.bg_h, landscape:f.landscape, fields:f.fields } : null,
      }, error:null });
    }
    return sbr(name, args);
  };
    await printCertificate();
    await new Promise(r => setTimeout(r, 200));
    const sent = window.__issued[0] || null;

    //  양식을 **고친 뒤** 옛 증서를 다시 뽑는다
    window.__printed = [];
    window.__DB.cert_forms[0].bg_url = 'about:blank#BARUN-SAE.png';
    window.__DB.cert_forms[0].name = '새로 고친 양식';
    await loadCertForms();
    certLog = [{
      id:'c1', lang:'ko', type:'admit', doc_label:'입 소 증 명 서', cert_no:'2026-0001',
      student_name:'가나다', birth:'2010-03-15', statement:'위 사람은 …',
      issue_date:'2026-11-14', org_name:'프로토스', seal_url:'about:blank#seal.png',
      form_snap:{ id:'f1', name:'우리 수료증 양식', bg_url:'about:blank#form.png',
                  bg_w:1240, bg_h:1754, fields: window.__FORM_FIELDS },
    }];
    reprintCertificate('c1');
    await new Promise(r => setTimeout(r, 150));
    return { sent, re: (window.__printed || []).join('\n') };
  });
  ok(r.sent && r.sent.form_id === 'f1', '발급할 때 form_id 를 보낸다', JSON.stringify(r.sent && r.sent.form_id));
  ok(/form\.png/.test(r.re), '다시 뽑으면 **그때 쓴** 배경이 나온다', r.re.includes('BARUN-SAE') ? '새 양식이 나왔다' : '');
  ok(!/BARUN-SAE/.test(r.re), '양식을 고친 뒤에도 옛 증서는 그때 모양 그대로다');
  await pg.close();
}

// ── ⑧ 편집 — 끌면 자리가 바뀌고, 저장 전까지 서버로 안 간다 ──────
console.log('\n⑧ 편집 화면 — 끌어서 자리 옮기기');
{
  const pg = await open1(b, [FORM({})]);
  await pg.evaluate(() => { certSubTab = 'form'; cfEditId = 'f1'; cfPickK = 'name'; renderCertForms(); });
  await pg.waitForTimeout(120);
  const before = await pg.evaluate(() => {
    const el = document.getElementById('cf-chip-name');
    const box = document.getElementById('cf-canvas').getBoundingClientRect();
    const r = el.getBoundingClientRect();
    return { has:!!el, cx: r.left + r.width/2, cy: r.top + r.height/2,
             box: { l:box.left, t:box.top, w:box.width, h:box.height },
             x: (window.__DB.cert_forms[0].fields.find(f=>f.k==='name')||{}).x };
  });
  ok(before.has, '꼬리표가 양식 위에 떠 있다');
  //  사람이 하듯 끌어 본다
  await pg.mouse.move(before.cx, before.cy);
  await pg.mouse.down();
  await pg.mouse.move(before.box.l + before.box.w * 0.25, before.box.t + before.box.h * 0.70, { steps: 6 });
  await pg.mouse.up();
  await pg.waitForTimeout(120);
  const after = await pg.evaluate(() => {
    const f = (cfEditing().fields || []).find(x => x.k === 'name') || {};
    return { x: f.x, y: f.y, dirty: cfDirty, wrote: (window.__upd || []).length };
  });
  ok(after.x > 0.18 && after.x < 0.33, '끌면 가로 자리가 바뀐다', 'x=' + (after.x||0).toFixed(3));
  ok(after.y > 0.62 && after.y < 0.78, '세로 자리도 바뀐다', 'y=' + (after.y||0).toFixed(3));
  ok(after.dirty === true, '「저장할 것이 있다」 고 표시된다');
  ok(after.wrote === 0, '끌 때마다 서버로 글이 가지 않는다 — 저장을 누를 때 한 번만', after.wrote + '번 썼다');
  //  저장
  const saved = await pg.evaluate(async () => {
    await cfSave();
    await new Promise(r => setTimeout(r, 120));
    return { wrote: (window.__upd || []).filter(u => u.t === 'cert_forms').length, dirty: cfDirty };
  });
  ok(saved.wrote === 1, '저장을 누르면 한 번 쓴다', saved.wrote + '번');
  ok(saved.dirty === false, '저장하면 표시가 사라진다');
  await pg.close();
}

// ── ⑨ 한 종류에 양식 둘은 못 올린다 ──────────────────────────────
console.log('\n⑨ 같은 종류에 양식을 또 올리면');
{
  const pg = await open1(b, [FORM({ kind:'admit' })]);
  const r = await pg.evaluate(async () => {
    certSubTab = 'form'; renderCertForms();
    await new Promise(r => setTimeout(r, 60));
    const sel = document.getElementById('cf-new-kind');
    const admitOpt = [...sel.options].find(o => o.value === 'admit');
    //  이미 있는 종류를 억지로 골라 올려 본다
    sel.value = 'admit';
    const n0 = (window.__ins || []).length;
    await cfUpload({ files: [new File([new Uint8Array([1,2,3])], 'a.png', { type:'image/png' })], value:'' });
    await new Promise(r => setTimeout(r, 150));
    return { disabled: !!(admitOpt && admitOpt.disabled), added: (window.__ins || []).length - n0,
             txt: document.body.innerText };
  });
  ok(r.disabled, '이미 양식이 있는 종류는 고르개에서 고를 수 없다');
  ok(r.added === 0, '억지로 골라도 둘째 양식이 안 들어간다', r.added + '개 들어갔다');
  ok(/이미 있어요/.test(r.txt), '왜 안 되는지 알려 준다');
  await pg.close();
}

done(b);
})();
