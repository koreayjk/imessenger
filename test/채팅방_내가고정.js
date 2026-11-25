//  📌 채팅방 — 나만 보는 고정
//
//  개선창 · 김시원 (그레이스 미니스트리, 11/21):
//    「개인적으로 중요한 채팅방은 위쪽에 고정을 할 수 있도록 했으면
//      좋겠습니다」
//
//  지금 있던 고정은 channels.pinned — **공동체 전체가 같이 보는** 고정이라
//  한 사람이 올리면 모두의 목록이 바뀝니다 (그래서 관리자만 만집니다).
//  「개인적으로」 는 그것과 다른 일이라, 사람마다 따로 적어 두는
//  덧층(my_channel_prefs)에 pinned 칸을 붙였습니다. 그 표의 규칙은
//  이미 member_id = auth.uid() 라 남의 고정은 보이지도 않습니다.
//
//  ⚠️ 1:1 대화에는 📌 를 달지 않습니다 — ★ 즐겨찾기가 이미 같은 일을 합니다.
//  ⚠️ 공동체 고정 방(전체공지 등)에도 달지 않습니다 — 관리자가 정합니다.
//
//  재는 것:
//   ① 📌 를 누르면 그 방이 고정 칸으로 올라간다
//   ② channels.pinned 는 **안 건드린다** (남의 목록이 안 바뀐다)
//   ③ 내 덧층에만 적힌다 · 다시 누르면 풀린다
//   ④ 전체공지는 여전히 고정 맨 위
//   ⑤ 1:1 과 공동체 고정 방에는 📌 가 없다
//   ⑥ 표에 안 들어갔으면 고정한 척하지 않는다
//   ⑦ 순서를 옮겨도 내 고정이 풀리지 않는다
const { launch, openApp, ok, done } = require('./_harness');

const CHANS = [
  { id:'c_ann',  name:'전체공지', kind:'topic', community_id:'c1', pinned:true,  sort:10, created_at:'2026-01-01' },
  { id:'c_a',    name:'환경부',   kind:'topic', community_id:'c1', pinned:false, sort:20, created_at:'2026-01-02' },
  { id:'c_b',    name:'찬양팀',   kind:'topic', community_id:'c1', pinned:false, sort:30, created_at:'2026-01-03' },
  { id:'c_dm',   name:'홍길동',   kind:'dm',    community_id:'c1', pinned:false, sort:40, created_at:'2026-01-04' },
];

async function openChat(b) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((cs) => {
    ME.id = 'me'; ME.name = '김시원'; ME.community_role = 'teacher';
    channels = JSON.parse(JSON.stringify(cs));
    window.__DB['channels'] = JSON.parse(JSON.stringify(cs));
    window.__DB['my_channel_prefs'] = [];
    myChPref = {}; commGroups = []; myGroups = []; channelGroups = [];
    //  ⚠️ isWatchOnly() 는 myChannelIds 가 아니라 **myRealChannelIds** 를 봅니다.
    //     이걸 안 채우면 모든 방이 「내가 안 들어간 방(지켜보는 방)」 이 되어
    //     📌 도 ★ 도 안 그려집니다 — 처음에 여기서 한 번 틀렸습니다.
    myChannelIds = new Set(cs.map(c => c.id));
    myRealChannelIds = new Set(cs.map(c => c.id));
    dmFavorites = new Set();
    unreadCounts = {};
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    document.getElementById('panel-body') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="panel-body"></div>');
    channels = sortChannels(channels);
    renderPanel();
  }, CHANS);
  await pg.waitForTimeout(300);
  return pg;
}

//  목록에서 「📌 고정」 칸에 들어 있는 방 이름들
const pinnedNames = (pg) => pg.evaluate(() => {
  const box = document.getElementById('panel-body');
  const kids = [...box.children];
  const i = kids.findIndex(k => /📌/.test(k.textContent || '') && k.className === 'section-label');
  if (i < 0) return [];
  const out = [];
  for (let j = i + 1; j < kids.length; j++) {
    if (kids[j].className === 'section-label') break;
    const nm = kids[j].querySelector('.ch-name');
    if (nm) out.push(nm.textContent.trim());
  }
  return out;
});

(async () => {
const b = await launch();

// ── ① 눌러서 올리기 ────────────────────────────────────────
console.log('\n① 📌 를 누르면');
{
  const pg = await openChat(b);
  const before = await pinnedNames(pg);
  const r = await pg.evaluate(async () => {
    await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 400));
    return { pinnedByMe: chanPinnedByMe(channels.find(c=>c.id==='c_b')),
             isPinned: chanPinned(channels.find(c=>c.id==='c_b')),
             toast: window.__toast.join('|') };
  });
  const after = await pinnedNames(pg);
  ok(before.join(',') === '전체공지', '처음엔 공동체 고정만 있다', before.join(','));
  ok(r.pinnedByMe, '내가 고정한 것으로 바뀐다', String(r.pinnedByMe));
  ok(after.includes('찬양팀'), '고정 칸으로 올라간다', after.join(','));
  ok(!after.includes('환경부'), '안 고른 방은 그대로 아래 있다', after.join(','));
  ok(/나만 보입니다/.test(r.toast), '나만 보인다고 알려 준다', r.toast);
  await pg.close();
}

// ── ② 남의 목록은 안 바뀐다 ────────────────────────────────
console.log('\n② 모두의 고정은 안 건드린다');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(async () => {
    await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 400));
    const chUpd = (window.__upd || []).filter(x => x.t === 'channels');
    const chIns = (window.__ins || []).filter(x => x.t === 'channels');
    const prefs = (window.__DB['my_channel_prefs'] || []);
    return { chUpd: chUpd.length, chIns: chIns.length,
             rowPinned: channels.find(c=>c.id==='c_b').pinned,
             prefs: prefs.map(p => [p.member_id, p.channel_id, p.pinned]) };
  });
  ok(r.chUpd === 0 && r.chIns === 0, 'channels 표에는 아무것도 안 보낸다', `upd ${r.chUpd} · ins ${r.chIns}`);
  ok(r.rowPinned === false, 'channels.pinned 는 그대로 false 다 ← 이게 핵심', String(r.rowPinned));
  ok(r.prefs.length === 1, '내 덧층에 한 줄만 적힌다', JSON.stringify(r.prefs));
  ok(r.prefs[0] && r.prefs[0][0] === 'me', '내 줄로 적힌다 (남의 줄이 아니다)', JSON.stringify(r.prefs[0]));
  ok(r.prefs[0] && r.prefs[0][2] === true, 'pinned 가 true 로 들어간다', JSON.stringify(r.prefs[0]));
  await pg.close();
}

// ── ③ 다시 누르면 풀린다 ───────────────────────────────────
console.log('\n③ 한 번 더 누르면');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(async () => {
    await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 300));
    window.__toast = [];
    await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 300));
    return { pinnedByMe: chanPinnedByMe(channels.find(c=>c.id==='c_b')),
             toast: window.__toast.join('|') };
  });
  const after = await pinnedNames(pg);
  ok(!r.pinnedByMe, '고정이 풀린다', String(r.pinnedByMe));
  ok(!after.includes('찬양팀'), '고정 칸에서 내려온다', after.join(','));
  ok(/고정을 풀었어요/.test(r.toast), '풀었다고 알려 준다', r.toast);
  await pg.close();
}

// ── ④ 전체공지는 늘 맨 위 ──────────────────────────────────
console.log('\n④ 전체공지 자리');
{
  const pg = await openChat(b);
  await pg.evaluate(async () => {
    await toggleMyPin('c_a'); await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 400));
  });
  const after = await pinnedNames(pg);
  ok(after[0] === '전체공지', '전체공지가 고정 칸 맨 위다', after.join(','));
  ok(after.length === 3, '내가 고정한 둘이 그 아래 붙는다', after.join(','));
  await pg.close();
}

// ── ⑤ 📌 를 어디에 다나 ────────────────────────────────────
console.log('\n⑤ 단추가 붙는 곳');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(() => {
    const box = document.getElementById('panel-body');
    //  ⚠️ 따옴표까지 맞춰 찾습니다. 'c_a' 로 품은 글자만 찾으면
    //     openChannel('c_ann') 이 먼저 걸려 **전체공지 줄**을 봅니다 —
    //     여기서도 한 번 틀렸습니다.
    const rowOf = (id) => [...box.querySelectorAll('.ch-row')]
      .find(x => (x.getAttribute('onclick') || '').includes("'" + id + "'"));
    const has  = (id) => { const r = rowOf(id); return r ? !!r.querySelector('[onclick*="toggleMyPin"]') : null; };
    const star = (id) => { const r = rowOf(id); return r ? !!r.querySelector('[onclick*="toggleDmFavorite"]') : null; };
    return { topic: has('c_a'), ann: has('c_ann'), dm: has('c_dm'), dmStar: star('c_dm') };
  });
  ok(r.topic === true,  '보통 방에는 📌 가 있다', String(r.topic));
  ok(r.ann === false,   '공동체 고정 방(전체공지)에는 없다 — 관리자가 정한다', String(r.ann));
  ok(r.dm === false,    '1:1 에는 없다', String(r.dm));
  ok(r.dmStar === true, '1:1 은 ★ 즐겨찾기가 그 일을 한다', String(r.dmStar));
  await pg.close();
}

// ── ⑥ 표에 안 들어갔을 때 ──────────────────────────────────
console.log('\n⑥ 막혔을 때');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(async () => {
    const real = sb.from;
    sb.from = (tb) => tb === 'my_channel_prefs'
      ? { upsert: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }
      : real(tb);
    window.__toast = [];
    await toggleMyPin('c_b');
    sb.from = real;
    return { pinnedByMe: chanPinnedByMe(channels.find(c=>c.id==='c_b')),
             toast: window.__toast.join('|') };
  });
  ok(!r.pinnedByMe, '고정한 척하지 않는다', String(r.pinnedByMe));
  ok(!/맨 위로 올렸어요/.test(r.toast), '올렸다고 말하지 않는다', r.toast);
  ok(/저장하지 못했어요/.test(r.toast), '못 했다고 말해 준다', r.toast);
  await pg.close();
}

// ── ⑥-2 칸을 아직 안 붙인 공동체 ───────────────────────────
console.log('\n⑥-2 SQL 을 안 돌렸을 때');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(async () => {
    const real = sb.from;
    sb.from = (tb) => tb === 'my_channel_prefs'
      ? { upsert: () => ({ select: () => Promise.resolve({ data:null,
          error: { message: 'column "pinned" of relation "my_channel_prefs" does not exist' } }) }) }
      : real(tb);
    window.__toast = [];
    await toggleMyPin('c_b');
    sb.from = real;
    return { toast: window.__toast.join('|'),
             pinnedByMe: chanPinnedByMe(channels.find(c=>c.id==='c_b')) };
  });
  ok(!r.pinnedByMe, '고정되지 않는다', String(r.pinnedByMe));
  ok(/채팅방_내가고정_DB설치\.sql/.test(r.toast), '어떤 SQL 을 돌릴지 알려 준다', r.toast);
  await pg.close();
}

// ── ⑦ 순서를 옮겨도 고정이 살아 있다 ────────────────────────
console.log('\n⑦ 순서를 옮긴 뒤');
{
  const pg = await openChat(b);
  const r = await pg.evaluate(async () => {
    await toggleMyPin('c_b');
    await new Promise(r => setTimeout(r, 300));
    //  savePrefs 는 sort·group_id 만 보냅니다 — pinned 가 날아가면 안 됩니다
    await savePrefs([{ id:'c_b', sort: 99, group_id: null }]);
    await new Promise(r => setTimeout(r, 300));
    return { pinnedByMe: chanPinnedByMe(channels.find(c=>c.id==='c_b')),
             pref: myChPref['c_b'],
             sentPinned: ((window.__DB['my_channel_prefs']||[]).find(p=>p.channel_id==='c_b')||{}).pinned };
  });
  ok(r.pinnedByMe, '자리를 옮겨도 내 고정은 그대로다', JSON.stringify(r.pref));
  ok(r.pref && r.pref.sort === 99, '새 자리도 적힌다', JSON.stringify(r.pref));
  await pg.close();
}

await b.close();
done();
})();
