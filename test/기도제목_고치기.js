//  🙏 기도제목 고치기 — 올린 사람 본인만
//
//  개선창 · 김연정 (프로토스, 11/16): 「수정 가능하도록」
//
//  ⚠️ 표의 UPDATE 규칙은 「같은 공동체면 누구나」 입니다 — 「함께 기도」
//     숫자를 올리려고 같은 줄을 고치기 때문입니다. 그래서 **서버는 남의 글
//     고치기를 막지 않습니다.** 화면에서 좁혀 두고, 서버는
//     db/기도제목_본인만고치기_DB설치.sql 의 방아쇠로 잠급니다.
//     여기서는 화면 쪽을 잽니다.
//
//  재는 것:
//   ① ✏️ 가 내 글에만 보이나
//   ② 고치면 그 줄만 바뀌나 (제목·본문·공개범위)
//   ③ 규칙에 막혀 0건이면 고쳤다고 거짓말하지 않나
//   ④ 남의 글은 함수를 직접 불러도 안 고쳐지나
//   ⑤ 제목을 비우면 막나 · 취소하면 그대로인가
const { launch, openApp, ok, done } = require('./_harness');

const MINE   = { id:'p1', title:'내 기도', body:'첫 줄\n둘째 줄', member_id:'me',
                 member_name:'김선생', scope:'전체', prayer_count:3,
                 created_at:'2026-11-16T00:00:00Z' };
const THEIRS = { id:'p2', title:'남의 기도', body:'남이 쓴 글', member_id:'other',
                 member_name:'홍길동', scope:'전체', prayer_count:1,
                 created_at:'2026-11-16T00:00:00Z' };

async function setup(b) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(([a, c]) => {
    prayers = [JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(c))];
    prayerJoined = {}; prayerCmts = {}; prayerCmtOpen = {}; prayerEditId = null;
    tcsGroups = [{ id:'g1', name:'3학년' }];
    window.__DB['prayers'] = [JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(c))];
    ['prayer-list','panel-body'].forEach(id => {
      document.getElementById(id) ||
        document.body.insertAdjacentHTML('beforeend', `<div id="${id}"></div>`);
    });
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    renderPrayerContent();
  }, [MINE, THEIRS]);
  return pg;
}
const card = (id) => `#prayer-${id}`;

(async () => {
const b = await launch();

// ── ① ✏️ 는 내 글에만 ───────────────────────────────────────
console.log('\n① 고치기 단추');
{
  const pg = await setup(b);
  const r = await pg.evaluate(() => ({
    mine:   !!document.querySelector('#prayer-p1 button[onclick*="startEditPrayer"]'),
    theirs: !!document.querySelector('#prayer-p2 button[onclick*="startEditPrayer"]'),
    theirsDel: !!document.querySelector('#prayer-p2 button[onclick*="deletePrayer"]'),
  }));
  ok(r.mine, '내 글에는 ✏️ 가 있다');
  ok(!r.theirs, '남의 글에는 ✏️ 가 없다');
  ok(r.theirsDel, '(관리자라) 지우기는 남의 글에도 그대로 있다');
  await pg.close();
}

// ── ② 고치면 그 줄만 바뀐다 ────────────────────────────────
console.log('\n② 고쳐서 저장');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    await startEditPrayer('p1');
    const opened = !!document.getElementById('pe-body-p1');
    //  지금 범위가 칩에 미리 골라져 있나
    const pre = document.querySelector('#pe-scope-p1 [data-selected="1"]');
    document.getElementById('pe-title-p1').value = '고친 제목';
    document.getElementById('pe-body-p1').value  = '고친 내용\n둘째 줄\n셋째 줄';
    const chip = document.querySelector('#pe-scope-p1 [data-scope="3학년"]');
    selectScope(chip, '3학년');
    await saveEditPrayer('p1');
    const upd = (window.__upd || []).filter(x => x.t === 'prayers');
    const el = document.getElementById('prayer-list');
    return {
      opened, pre: pre && pre.dataset.scope,
      editing: prayerEditId,
      row: prayers.find(x => x.id === 'p1'),
      other: prayers.find(x => x.id === 'p2'),
      brs: el.querySelector('#prayer-p1 p').querySelectorAll('br').length,
      text: el.innerText,
      toast: window.__toast.join('|'),
    };
  });
  ok(r.opened, '✏️ 를 누르면 고치는 칸이 열린다');
  ok(r.pre === '전체', '지금 공개범위가 미리 골라져 있다', r.pre);
  ok(r.row.title === '고친 제목', '제목이 바뀌었다', r.row.title);
  ok(r.row.body === '고친 내용\n둘째 줄\n셋째 줄', '본문이 바뀌었다', JSON.stringify(r.row.body));
  ok(r.row.scope === '3학년', '공개범위도 바뀌었다', r.row.scope);
  ok(r.row.prayer_count === 3, '함께 기도 숫자는 건드리지 않았다', r.row.prayer_count);
  ok(r.other.title === '남의 기도', '남의 글은 그대로다', r.other.title);
  ok(r.editing === null, '저장하면 고치는 칸이 닫힌다', r.editing);
  ok(r.brs === 2, '고친 글의 줄바꿈도 살아 있다', r.brs);
  ok(/고쳤어요/.test(r.toast), '고쳤다고 알려 준다', r.toast);
  await pg.close();
}

// ── ③ 규칙에 막혀 0건이면 ──────────────────────────────────
console.log('\n③ 0건으로 돌아왔을 때');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    await startEditPrayer('p1');
    document.getElementById('pe-title-p1').value = '막힐 제목';
    const real = sb.from;
    sb.from = (t) => t === 'prayers'
      ? { update: () => ({ eq: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }) }
      : real(t);
    window.__toast = [];
    await saveEditPrayer('p1');
    sb.from = real;
    return { title: prayers.find(x => x.id === 'p1').title, toast: window.__toast.join('|') };
  });
  ok(r.title === '내 기도', '화면에도 고친 척하지 않는다', r.title);
  ok(!/고쳤어요/.test(r.toast), '고쳤다고 하지 않는다', r.toast);
  ok(/권한이 없어요/.test(r.toast), '권한이 없다고 말해 준다', r.toast);
  await pg.close();
}

// ── ④ 남의 글은 함수를 직접 불러도 ─────────────────────────
console.log('\n④ 남의 글에 함수를 직접 부르면');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    window.__toast = [];
    await startEditPrayer('p2');
    const openedOther = !!document.getElementById('pe-body-p2');
    await saveEditPrayer('p2');
    const upd = (window.__upd || []).filter(x => x.t === 'prayers');
    return { openedOther, editing: prayerEditId, upd: upd.length, toast: window.__toast.join('|') };
  });
  ok(!r.openedOther, '남의 글은 고치는 칸이 안 열린다');
  ok(r.editing === null, '고치는 중으로 바뀌지도 않는다', r.editing);
  ok(r.upd === 0, '표에 아무것도 안 보낸다', r.upd);
  ok(/내가 올린 것만/.test(r.toast), '내 것만 고칠 수 있다고 말해 준다', r.toast);
  await pg.close();
}

// ── ⑤ 빈 제목 · 취소 ───────────────────────────────────────
console.log('\n⑤ 빈 제목과 취소');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    await startEditPrayer('p1');
    document.getElementById('pe-title-p1').value = '   ';
    window.__toast = [];
    await saveEditPrayer('p1');
    const blocked = { upd: (window.__upd||[]).filter(x=>x.t==='prayers').length,
                      toast: window.__toast.join('|') };
    //  취소하면 적던 것이 버려지고 원래 글이 돌아온다
    document.getElementById('pe-title-p1').value = '버릴 제목';
    cancelEditPrayer();
    return { blocked, editing: prayerEditId,
             title: prayers.find(x=>x.id==='p1').title,
             text: document.getElementById('prayer-list').innerText };
  });
  ok(r.blocked.upd === 0, '제목이 비면 보내지 않는다', r.blocked.upd);
  ok(/제목을 적어주세요/.test(r.blocked.toast), '제목을 적으라고 말해 준다', r.blocked.toast);
  ok(r.editing === null, '취소하면 고치는 칸이 닫힌다', r.editing);
  ok(r.title === '내 기도', '취소하면 적던 것은 버려진다', r.title);
  ok(/내 기도/.test(r.text), '원래 글이 다시 보인다');
  await pg.close();
}

// ── ⑥ 올리기 폼도 같은 칩을 쓴다 ───────────────────────────
//   selectScope() 가 앞서 고른 칩을 못 꺼서, 고른 것이 둘이 되고
//   submitPrayer() 는 첫 번째('전체')를 읽었습니다. 한 그룹에게만
//   나누려고 골라도 **공동체 전체로 올라갔습니다.**
console.log('\n⑥ 올릴 때 그룹을 고르면');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    await showPrayerForm();
    document.getElementById('ptitle').value = '그룹에만';
    document.getElementById('pbody').value  = '3학년만 봤으면 해요';
    const form = document.getElementById('ptitle').closest('.prayer-card');
    const chip = form.querySelector('[data-scope="3학년"]');
    selectScope(chip, '3학년');
    const picked = [...form.querySelectorAll('[data-selected]')].map(x => x.dataset.scope);
    await submitPrayer(form.querySelector('[onclick^="submitPrayer"]'));
    const ins = (window.__ins || []).filter(x => x.t === 'prayers');
    return { picked, scope: ins.length ? ins[0].rows[0].scope : '(안 보냄)' };
  });
  ok(r.picked.length === 1, '고른 칩은 하나뿐이다 (앞서 고른 것이 꺼진다)', r.picked.join(','));
  ok(r.picked[0] === '3학년', '고른 것이 3학년이다', r.picked.join(','));
  ok(r.scope === '3학년', '올릴 때 3학년으로 나간다 (전체로 새지 않는다)', r.scope);
  await pg.close();
}

await b.close();
done();
})();
