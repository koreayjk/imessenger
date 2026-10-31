// 🧪 시험 밑판 — 진짜 index.html 을 띄우고, Supabase 자리에 가짜를 끼웁니다.
//
//  화면을 '재서' 확인합니다. 코드를 읽어서 그럴듯하면 통과시키는 시험은
//  고치고 나서도 통과해 버립니다. 그래서 늘 되돌려 보고 ❌ 가 나오는지까지
//  확인합니다.
const fs = require('fs'), path = require('path');

//  ⚠️ 컨테이너가 바뀌면 playwright 와 크로미움 자리가 달라진다. 한 자리에
//     못 박아 두면 그때마다 시험이 통째로 안 돈다 — 찾아서 쓴다.
function pick(cands, what) {
  for (const c of cands) { try { if (fs.existsSync(c)) return c; } catch (_) {} }
  throw new Error(what + ' 를 못 찾았습니다. 찾아본 곳:\n  ' + cands.join('\n  '));
}
function findPlaywright() {
  const cands = [
    '/opt/node-tools/node_modules/playwright-core',
    '/opt/node22/lib/node_modules/playwright/node_modules/playwright-core',
    'playwright-core', 'playwright',
  ];
  for (const c of cands) { try { return require(c); } catch (_) {} }
  throw new Error('playwright 를 못 찾았습니다');
}
function findChrome() {
  const roots = ['/opt/pw-browsers'];
  const names = ['chrome-linux64/chrome', 'chrome-linux/chrome'];
  const out = [];
  for (const r of roots) {
    let dirs = [];
    try { dirs = fs.readdirSync(r).filter(d => /^chromium/.test(d)).sort().reverse(); } catch (_) {}
    for (const d of dirs) for (const n of names) out.push(path.join(r, d, n));
  }
  out.push('/usr/bin/chromium', '/usr/bin/google-chrome');
  return pick(out, '크로미움');
}
const { chromium } = findPlaywright();
const ROOT = path.resolve(__dirname, '..');
const STUB = fs.readFileSync(path.join(__dirname, 'stub.js'), 'utf8');

const state = { pass: 0, fail: 0 };
const ok = (c, m) => {
  if (c) { state.pass++; console.log('  ✅', m); }
  else   { state.fail++; console.log('  ❌', m); }
};

//  가짜 Supabase — from()/rpc() 가 메모리 위의 표를 다룹니다.
function dbScript() {
  return `(() => {
    const DB = window.__seed();
    window.__DB = DB; window.__ins = []; window.__upd = []; window.__err = null;
    let seq = 0;
    const mkq = (t) => { const q = { _t:t, _eq:{} };
      ['limit','neq','is','gte','lte','lt','gt','not','range','or','filter','contains']
        .forEach(k => q[k] = function(){ return this; });
      q.order = function(k, o){ (this._ord = this._ord || []).push([k, !(o && o.ascending === false)]); return this; };
      q.in = function(k,v){ this._in=[k,v]; return this; };
      q.select = function(){ return this; };
      q.single = q.maybeSingle = function(){ this._s=1; return this; };
      q.eq = function(k,v){ this._eq[k]=v; return this; };
      q.insert = function(v){ this._i=v; return this; };
      q.upsert = function(v){ this._i=v; return this; };
      q.update = function(v){ this._u=v; return this; };
      q.delete = function(){ this._d=1; return this; };
      q.then = function(res, rej){
        if (window.__err && window.__err.table === this._t)
          return Promise.resolve({ data:null, error: window.__err.e }).then(res, rej);
        if (this._i) {
          const arr = Array.isArray(this._i) ? this._i : [this._i];
          const rows = arr.map(x => Object.assign({ id: this._t+'-'+(++seq), created_at:new Date().toISOString() }, x));
          (DB[this._t] = DB[this._t] || []).push(...rows);
          window.__ins.push({ t:this._t, rows });
          return Promise.resolve({ data: this._s ? rows[0] : rows, error:null }).then(res, rej);
        }
        let rows = (DB[this._t] || []).slice();
        Object.entries(this._eq).forEach(([k,v]) => { rows = rows.filter(x => String(x[k]) === String(v)); });
        if (this._in) { const [k,vs] = this._in; rows = rows.filter(x => vs.map(String).includes(String(x[k]))); }
        if (this._u) { window.__upd.push({ t:this._t, eq:{...this._eq}, u:this._u });
          rows.forEach(r => Object.assign(r, this._u));
          return Promise.resolve({ data: rows.map(r => ({ id:r.id })), error:null }).then(res, rej); }
        if (this._d) { DB[this._t] = (DB[this._t]||[]).filter(x => !rows.includes(x));
          return Promise.resolve({ data: rows.map(r => ({ id:r.id })), error:null }).then(res, rej); }
        (this._ord || []).slice().reverse().forEach(([k, asc]) => {
          rows.sort((a,b) => String(a[k]||'').localeCompare(String(b[k]||'')) * (asc ? 1 : -1));
        });
        if (this._s) return Promise.resolve({ data: rows[0] || null, error:null }).then(res, rej);
        return Promise.resolve({ data: rows, error:null }).then(res, rej);
      };
      return q; };
    window.supabase = { createClient: () => ({
      from: t => mkq(t), rpc: () => mkq('_rpc'),
      channel: () => ({ on(){return this}, subscribe(){return this}, send(){return Promise.resolve('ok')} }),
      removeChannel(){},
      storage:{ from: () => ({ getPublicUrl: () => ({ data:{ publicUrl:'' } }) }) },
      functions:{ invoke: async () => ({ data:null, error:null }) },
      auth:{ getSession: async () => ({ data:{ session:null } }), onAuthStateChange(){}, signOut: async () => ({}) },
    }) };
  })();`;
}

async function launch() {
  return chromium.launch({ executablePath: findChrome() });
}

//  as: 'teacher'(기본) | 'parent' | 'student'
async function openApp(b, o = {}) {
  const pg = await b.newPage(Object.assign(
    { viewport: o.viewport || { width: 1280, height: 950 } },
    o.ua ? { userAgent: o.ua } : {}));
  pg.on('pageerror', e => console.log('  ⚠️', e.message.slice(0, 130)));
  //  🚧 바깥으로 나가는 길을 전부 막는다.
  //
  //  index.html 은 19줄에서 supabase-js 를 CDN 에서 받아옵니다. 그게 받아지면
  //  window.supabase 가 진짜 라이브러리로 덮어써지고, 시험이 **운영 데이터베이스에**
  //  말을 걸게 됩니다. 실제로 그런 일이 있었습니다(select 라 읽기만 했지만,
  //  insert 를 쓰는 시험이었다면 운영에 글이 들어갔을 겁니다).
  //  파일에서 읽는 것 말고는 전부 끊습니다.
  await pg.route('**', (route) => {
    const u = route.request().url();
    if (u.startsWith('file://') || u.startsWith('data:') || u.startsWith('blob:')) return route.continue();
    return route.abort();
  });
  await pg.addInitScript(STUB);
  await pg.addInitScript(dbScript());
  await pg.goto('file://' + path.join(ROOT, 'index.html'));
  await pg.waitForTimeout(900);
  await pg.evaluate((who) => {
    const s = window.__seed();
    const WHO = {
      parent:  { id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent',  initials:'홍', color:'#be5b2a' },
      student: { id:'s1', name:'홍길동',   community_id:'c1', community_role:'student', initials:'홍', color:'#2a5298' },
      teacher: { id:'me', name:'김선생',   community_id:'c1', community_role:'community_admin', initials:'김', color:'#1d3a5f' },
    };
    ME = WHO[who] || WHO.teacher;
    members = {}; s.members.forEach(m => { m.color = avColor(m.color); members[m.id] = m; });
    members[ME.id] = ME;
    channels = s.channels.slice();
    myChannelIds = new Set(channels.map(c => c.id));
    myRealChannelIds = new Set(myChannelIds);
    myBlocks = new Set();
    try { schoolStudents = s.members.filter(m => m.community_role === 'student'); } catch (_) {}
    const sp = document.getElementById('splash'); if (sp) sp.remove();
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app').style.display = 'flex';
  }, o.as || 'teacher');
  await pg.waitForTimeout(250);
  return pg;
}

function done() {
  console.log('\n통과 ' + state.pass + ' · 실패 ' + state.fail);
  process.exit(state.fail ? 1 : 0);
}

module.exports = { launch, openApp, ok, done, state, ROOT };
