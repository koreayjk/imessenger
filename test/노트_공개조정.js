//  🛠 관리자가 노트 공개 상태를 조정하기 (개선창 ⑧ · 양회광 · IM HQ · 11/03)
//
//    "이미 올라온 노트들을 관리자가 공개상태 조정을 할 수 있도록 되면 좋겠습니다."
//
//  재 보니 notes_update 가 `user_id = auth.uid()` 뿐이었습니다. 관리자가
//  눌러도 표가 **조용히 0줄** 을 돌려주고 끝납니다. 그래서 서버에 공개 칸만
//  만지는 길(admin_set_note_visibility) 을 하나 내고, 운영 DB 에서 선을
//  8가지로 재서 확인했습니다. 여기서는 화면이 그 선을 지키는지 잽니다.
//
//  ★ 지키는 선
//   ① 남의 「나만 보기」 노트는 관리자도 못 봅니다 → 단추가 아예 없습니다.
//   ② 남의 노트 '내용' 은 못 고칩니다 → 공개 칸만 바꿉니다.
//   ③ 몰래 바뀌면 안 됩니다 → 글쓴이에게 한 줄 보냅니다.
const { launch, openApp, ok, done } = require('./_harness');

const MEMBERS = [
  { id:'me',  name:'김선생',  community_id:'c1', community_role:'community_admin', status:'approved' },
  { id:'u1',  name:'전여진',  community_id:'c1', community_role:'staff',   status:'approved' },
  { id:'u2',  name:'박유빈',  community_id:'c1', community_role:'student', status:'approved' },
];
const NOTES = [
  { id:'n-pub',  user_id:'u1', author_name:'전여진', community_id:'c1',
    title:'공동체 공개 노트', body:'본문', visibility:'community', share_members:[], share_groups:[] },
  { id:'n-sel',  user_id:'u1', author_name:'전여진', community_id:'c1',
    title:'고른 사람만 노트', body:'본문', visibility:'selected', share_members:['me'], share_groups:[] },
  { id:'n-priv', user_id:'u2', author_name:'박유빈', community_id:'c1',
    title:'남의 비공개 노트', body:'본문', visibility:'private', share_members:[], share_groups:[] },
  { id:'n-mine', user_id:'me', author_name:'김선생', community_id:'c1',
    title:'내 공개 노트', body:'본문', visibility:'community', share_members:[], share_groups:[] },
];

//  진짜 화면을 띄우고, 노트 하나를 열어 둔 상태로 만든다.
async function openNote(b, o) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((d) => {
    members = {};
    d.MEMBERS.forEach(m => { members[m.id] = Object.assign({}, m); });
    ME = members['me'];
    ME.community_role = d.role;
    VIEW_CID = d.viewCid || null;
    imNotes = d.NOTES.map(n => Object.assign({}, n));
    imNoteCur = imNotes.find(x => x.id === d.noteId) || null;
    window.__DB.notes = imNotes.map(n => Object.assign({}, n));
  }, Object.assign({ MEMBERS, NOTES }, o));
  return pg;
}

(async () => {
const b = await launch();

// ── ① 누구에게 '공개 조정' 단추가 보이나 ─────────────────────
//  화면을 읽어서 고르는 게 아니라, **진짜 편집기 머리줄 HTML** 을 받아
//  거기에 단추가 있는지 잽니다.
console.log('\n① 누구에게 단추가 보이나');
{
  for (const [role, viewCid, noteId, want, label] of [
    ['community_admin', null, 'n-pub',  true,  '관리자 · 남의 🌐 노트'],
    ['community_admin', null, 'n-sel',  true,  '관리자 · 남의 👥 노트'],
    ['super_admin',     null, 'n-pub',  true,  '총관리자 · 남의 🌐 노트'],
    ['vice_admin',      null, 'n-pub',  true,  '부총관리자 · 내 공동체'],
    ['vice_admin',      'c9', 'n-pub',  false, '부총관리자 · 남의 공동체 보는 중'],
    ['teacher',         null, 'n-pub',  false, '교사'],
    ['staff',           null, 'n-pub',  false, '간사'],
    ['student',         null, 'n-pub',  false, '학생'],
    ['community_admin', null, 'n-mine', false, '관리자 · 내 노트 (원래 공유 단추가 있다)'],
  ]) {
    const pg = await openNote(b, { role, viewCid, noteId });
    const r = await pg.evaluate(() => {
      const html = imNoteEditorHtml();
      return { btn: /imOpenAdminVis\(\)/.test(html), can: canAdminNoteVis(imNoteCur) };
    });
    await pg.close();
    ok(r.btn === want && r.can === want,
       `${label} — 단추 ${want ? '보인다' : '없다'} (${r.btn ? '보임' : '없음'})`);
  }
}

// ── ② 남의 「나만 보기」 노트는 손도 못 댄다 ─────────────────
console.log('\n② 남의 비공개 노트');
{
  const pg = await openNote(b, { role:'community_admin', noteId:'n-priv' });
  const r = await pg.evaluate(async () => {
    const can = canAdminNoteVis(imNoteCur);
    window.confirm = () => true;
    const before = window.__rpc.length;
    await imAdminSetVis('community');            // 직접 불러도
    return { can, called: window.__rpc.length - before };
  });
  await pg.close();
  ok(r.can === false, '단추 자체가 없다');
  ok(r.called === 0, '함수를 직접 불러도 서버에 아무것도 안 보낸다 ← 서버도 막는다');
}

// ── ③ 모달 — 지금 상태는 못 누르고, 반대쪽만 누를 수 있다 ───
console.log('\n③ 조정 창');
{
  const pg = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r = await pg.evaluate(() => {
    imOpenAdminVis();
    const m = document.getElementById('im-admvis-modal');
    const rows = [...m.querySelectorAll('div[style*="border-radius:12px"]')]
      .filter(x => /imAdminSetVis|지금 상태|Current/.test(x.outerHTML));
    return {
      open: !!m,
      txt: m.innerText,
      pickable: [...m.querySelectorAll('[onclick*="imAdminSetVis"]')]
                  .map(x => (x.getAttribute('onclick').match(/'(\w+)'/) || [])[1]),
      nowMark: /지금 상태/.test(m.innerText),
      selNote: /고른 사람만.*이에요|clears that list/.test(m.innerText),
    };
  });
  await pg.close();
  ok(r.open, '조정 창이 뜬다');
  ok(r.pickable.join(',') === 'private',
     '🌐 인 노트에서는 🔒 만 누를 수 있다 (지금 상태는 못 누른다)');
  ok(r.nowMark, "지금 상태에 '지금 상태' 라고 적힌다");
  ok(/전여진/.test(r.txt), '글쓴이 이름이 보인다');
  ok(/노트 제목과 내용은 관리자도 고칠 수 없어요/.test(r.txt),
     "'내용은 못 고친다' 고 미리 말해준다");
  ok(!r.selNote, '🌐 노트에는 명단 안내가 안 뜬다');
}
{
  const pg = await openNote(b, { role:'community_admin', noteId:'n-sel' });
  const r = await pg.evaluate(() => {
    imOpenAdminVis();
    const m = document.getElementById('im-admvis-modal');
    return {
      pickable: [...m.querySelectorAll('[onclick*="imAdminSetVis"]')]
                  .map(x => (x.getAttribute('onclick').match(/'(\w+)'/) || [])[1]).sort(),
      selNote: /고른 명단은 지워집니다/.test(m.innerText),
      nowMark: /지금 상태/.test(m.innerText),
    };
  });
  await pg.close();
  ok(r.pickable.join(',') === 'community,private',
     '👥 노트는 양쪽 다 누를 수 있다 (지금 상태가 둘 중 어느 것도 아니다)');
  ok(r.selNote, '고른 명단이 지워진다고 미리 알려준다');
  ok(!r.nowMark, "👥 노트에는 '지금 상태' 표가 없다");
}

// ── ④ 🔒 로 내리기 ──────────────────────────────────────────
console.log('\n④ 🔒 로 내리기');
{
  const pg = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r = await pg.evaluate(async () => {
    window.confirm = () => true;
    let said = '', dm = null;
    window.imToast = (m) => { said += m + '|'; };
    window.dmSendTextTo = async (id, text) => { dm = { id, text }; return true; };
    imOpenAdminVis();
    await imAdminSetVis('private');
    return {
      said, dm,
      rpc: window.__rpc[window.__rpc.length - 1],
      left: imNotes.map(n => n.id),
      cur: imNoteCur ? imNoteCur.id : null,
      modal: !!document.getElementById('im-admvis-modal'),
      upd: window.__upd.length,
    };
  });
  await pg.close();
  ok(r.rpc && r.rpc.name === 'admin_set_note_visibility', '공개 칸만 만지는 길로 보낸다');
  ok(r.rpc && r.rpc.args && r.rpc.args.p_note === 'n-pub' && r.rpc.args.p_vis === 'private',
     '어느 노트를 어떻게 바꿀지 그대로 보낸다');
  ok(r.upd === 0, 'notes 표를 직접 고치지 않는다 ← 그러면 제목·본문까지 열린다');
  ok(r.dm && r.dm.id === 'u1', '글쓴이에게 알린다');
  ok(r.dm && /비공개로 내렸어요/.test(r.dm.text) && /김선생/.test(r.dm.text),
     '누가 왜 바꿨는지 적어 보낸다');
  ok(r.dm && /노트와 내용은 그대로/.test(r.dm.text), '노트가 지워진 게 아니라고 알려준다');
  ok(!r.left.includes('n-pub'), '관리자 눈에서도 사라진다 (이제 RLS 가 안 돌려준다)');
  ok(r.cur === null, '목록으로 돌아간다');
  ok(!r.modal, '창이 닫힌다');
  ok(/비공개로 내렸어요/.test(r.said) && /글쓴이에게 알렸어요/.test(r.said),
     '한 줄로 알려준다');
}

// ── ⑤ 🌐 로 올리기 ─────────────────────────────────────────
console.log('\n⑤ 🌐 로 올리기');
{
  const pg = await openNote(b, { role:'community_admin', noteId:'n-sel' });
  const r = await pg.evaluate(async () => {
    window.confirm = () => true;
    let said = '', dm = null;
    window.imToast = (m) => { said += m + '|'; };
    window.dmSendTextTo = async (id, text) => { dm = { id, text }; return true; };
    await imAdminSetVis('community');
    const n = imNotes.find(x => x.id === 'n-sel');
    return { said, dm, vis: n.visibility, mem: n.share_members.length,
             left: imNotes.map(x => x.id), cur: imNoteCur ? imNoteCur.id : null,
             rpc: window.__rpc[window.__rpc.length - 1] };
  });
  await pg.close();
  ok(r.rpc.args.p_vis === 'community', '공동체 공개로 보낸다');
  ok(r.vis === 'community', '화면에서도 🌐 가 된다');
  ok(r.mem === 0, '고른 명단을 비운다 (서버도 비운다)');
  ok(r.left.includes('n-sel') && r.cur === 'n-sel', '열어 둔 노트는 그대로 열려 있다');
  ok(/공동체 전체에 공개했어요/.test(r.said), '한 줄로 알려준다');
}

// ── ⑥ 거짓말하지 않는다 ────────────────────────────────────
console.log('\n⑥ 거짓말하지 않는다');
{
  //  ⑥-1 물었을 때 '아니오' 면 아무것도 안 한다
  const pg1 = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r1 = await pg1.evaluate(async () => {
    window.confirm = () => false;
    const before = window.__rpc.length;
    await imAdminSetVis('private');
    return { called: window.__rpc.length - before, left: imNotes.map(n => n.id) };
  });
  await pg1.close();
  ok(r1.called === 0 && r1.left.includes('n-pub'), "'아니오' 면 아무것도 안 바뀐다");

  //  ⑥-2 서버가 막으면 바꿨다고 하지 않는다
  const pg2 = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r2 = await pg2.evaluate(async () => {
    window.confirm = () => true;
    let said = '';
    window.imToast = (m) => { said += m + '|'; };
    window.dmSendTextTo = async () => true;
    window.__err = { table:'rpc:admin_set_note_visibility', e:{ message:'관리자만 할 수 있습니다.' } };
    await imAdminSetVis('private');
    return { said, left: imNotes.map(n => n.id), cur: imNoteCur ? imNoteCur.id : null };
  });
  await pg2.close();
  ok(/관리자만 할 수 있습니다/.test(r2.said), '서버가 한 말을 그대로 보여준다');
  ok(!/내렸어요/.test(r2.said), "'내렸어요' 라고 거짓말하지 않는다");
  ok(r2.left.includes('n-pub') && r2.cur === 'n-pub', '목록에서 빼지 않는다');

  //  ⑥-3 알림이 안 가면 '알렸어요' 라고 하지 않는다
  const pg3 = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r3 = await pg3.evaluate(async () => {
    window.confirm = () => true;
    let said = '';
    window.imToast = (m) => { said += m + '|'; };
    window.dmSendTextTo = async () => false;      // 방을 못 만들었다
    await imAdminSetVis('private');
    return { said, left: imNotes.map(n => n.id) };
  });
  await pg3.close();
  ok(/비공개로 내렸어요/.test(r3.said), '바뀐 건 바뀐 대로 알려준다');
  ok(!/알렸어요/.test(r3.said), "알림이 안 갔으면 '알렸어요' 라고 안 한다");
  ok(!r3.left.includes('n-pub'), '바뀐 것 자체는 되돌리지 않는다');

  //  ⑥-4 '고른 사람만' 은 관리자가 대신 고르지 않는다
  const pg4 = await openNote(b, { role:'community_admin', noteId:'n-pub' });
  const r4 = await pg4.evaluate(async () => {
    window.confirm = () => true;
    const before = window.__rpc.length;
    await imAdminSetVis('selected');
    return { called: window.__rpc.length - before };
  });
  await pg4.close();
  ok(r4.called === 0, "'고른 사람만' 은 보내지도 않는다 ← 서버도 그 값을 받지 않는다");
}

await b.close();
done();
})();
