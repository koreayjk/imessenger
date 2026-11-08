//  🌐 채팅 — 모든 공동체가 들어오는 그룹
//
//    "기본은 소속공동체만 가능한데 이 그룹안에서의 채팅방만
//     모든 공동체 멤버들중에 초대할수있도록"
//
//  그 선을 글로 못 박습니다. 깃발(cross_community)이 선 그룹 안의 방만
//  모든 공동체에서 초대하고, 그 밖은 전과 똑같이 우리 공동체만 입니다.
const { launch, openApp, ok, done } = require('./_harness');

const GROUPS = [
  { id:'g1', community_id:'c1', name:'사역팀',     sort:10 },                        // 우리 공동체
  { id:'g2', community_id:'c9', name:'남의공동체', sort:10 },                        // 남의 공동체
  { id:'g3', community_id:'c1', name:'연합모임',   sort:20, cross_community:true },   // 🌐
  { id:'g4', community_id:'c9', name:'연합기도',   sort:30, cross_community:true },   // 🌐 (남의 공동체에 있어도 보여야 함)
];
//  모든 공동체 후보 — 서버 함수 cross_invite_candidates 가 돌려줄 모양
const CAND = [
  { id:'me', name:'김선생',  community_id:'c1', community_role:'community_admin', community_name:'IM HQ' },
  { id:'a1', name:'한학생',  community_id:'c1', community_role:'student',         community_name:'IM HQ' },
  { id:'b1', name:'미국학생', community_id:'c9', community_role:'student',        community_name:'IM USA' },
  { id:'b2', name:'미국간사', community_id:'c9', community_role:'staff',          community_name:'IM USA' },
];

(async () => {
const b = await launch();

// ── ① 어떤 그룹이 보이나 ─────────────────────────────────────
console.log('\n① 어떤 그룹이 보이나');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (G) => {
    window.__DB.channel_groups = G;
    await loadChannelGroups();
    return {
      names: commGroups.map(g => g.name),
      cross: commGroups.filter(g => isCrossGroup(g)).map(g => g.name),
    };
  }, GROUPS);

  ok(r.names.includes('사역팀'), '우리 공동체 그룹이 보인다');
  ok(!r.names.includes('남의공동체'),
     '남의 공동체 그룹은 안 보인다 ← 기본은 소속공동체만');
  ok(r.names.includes('연합모임') && r.names.includes('연합기도'),
     '🌐 그룹은 어느 공동체에 있어도 보인다');
  ok(r.cross.length === 2, '🌐 로 셈해지는 것이 둘이다');
  await pg.close();
}

// ── ② 방 만들기 — 그룹에 따라 초대 범위가 바뀐다 ──────────────
console.log('\n② 방 만들기 — 초대 범위');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.channel_groups = d.GROUPS;
    await loadChannelGroups();
    ME.community_role = 'super_admin';
    window.__DB['rpc:cross_invite_candidates'] = d.CAND;
    showAddChannelModal();

    const out = {};
    const read = () => {
      const list = document.getElementById('new-ch-members');
      return {
        note: document.getElementById('new-ch-scope').innerText,
        noteOn: document.getElementById('new-ch-scope').style.display !== 'none',
        comms: [...list.querySelectorAll('[data-cross-comm]')].map(x => x.dataset.crossComm),
        //  한 줄에 [머리글자, 이름, 역할, ✓] 이 들어온다 — 이름은 두 번째
        names: [...list.querySelectorAll('[data-mid]')]
                 .map(x => (x.innerText.split('\n').map(s => s.trim()).filter(Boolean)[1] || '')),
        picked: [...selectedNewChMembers],
      };
    };
    //  그룹 없음
    document.getElementById('new-ch-group').value = '';
    await onNewChGroupChange();
    out.none = read();
    //  우리 공동체 그룹
    document.getElementById('new-ch-group').value = 'g1';
    await onNewChGroupChange();
    out.comm = read();
    //  🌐 그룹
    document.getElementById('new-ch-group').value = 'g3';
    await onNewChGroupChange();
    out.cross = read();

    out.choices = [...document.querySelectorAll('#new-ch-group option')].map(o => o.value);
    closeAddModal();
    return out;
  }, { GROUPS, CAND });

  ok(r.none.comms.length === 0, '그룹 없음 — 공동체 머리글이 없다 (우리 공동체만)');
  ok(r.comm.comms.length === 0, '우리 공동체 그룹 — 여기도 우리 공동체만');
  ok(/우리 공동체 사람만/.test(r.comm.note), '우리 공동체만이라고 적어준다');

  ok(r.cross.comms.length === 2,
     '🌐 그룹 — 공동체별로 묶여 나온다 ← 이게 요청이었다');
  ok(r.cross.comms[0] === 'IM HQ', '내 공동체가 맨 위로 온다');
  ok(r.cross.names.includes('미국학생') && r.cross.names.includes('미국간사'),
     '다른 공동체 사람이 후보에 들어온다');
  ok(/모든 공동체/.test(r.cross.note), '모든 공동체라고 또박또박 적어준다');
  ok(/공동체 2곳/.test(r.cross.note) && /4명/.test(r.cross.note),
     '몇 곳 · 몇 명인지 보여준다');
  ok(r.cross.picked.length === 1 && r.cross.picked[0] === 'me',
     '🌐 방은 아무도 안 고른 채로 시작한다 ← 전원이 든 방을 모르고 만들지 않게');
  ok(r.comm.picked.length > 1,
     '우리 공동체 그룹은 전과 같이 전체 선택으로 시작한다');
  ok(r.choices.includes('g3') && r.choices.includes('g4'),
     '🌐 그룹을 고를 수 있다');
  await pg.close();
}

// ── ③ 🌐 방은 총·부총관리자만 만든다 ─────────────────────────
console.log('\n③ 🌐 방은 총·부총관리자만');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (G) => {
    window.__DB.channel_groups = G;
    await loadChannelGroups();
    const out = {};
    for (const role of ['super_admin','vice_admin','community_admin','teacher','staff']) {
      ME.community_role = role;
      showAddChannelModal();
      out[role] = {
        can: canMakeCrossChannel(),
        choices: [...document.querySelectorAll('#new-ch-group option')].map(o => o.value),
      };
      closeAddModal();
    }
    return out;
  }, GROUPS);

  ok(r.super_admin.can && r.vice_admin.can, '총·부총관리자는 만들 수 있다');
  ok(!r.community_admin.can && !r.teacher.can && !r.staff.can,
     '공동체 관리자·교사·간사는 못 만든다');
  ok(r.super_admin.choices.includes('g3'), '총관리자 고르개에 🌐 그룹이 있다');
  ok(!r.community_admin.choices.includes('g3'),
     '공동체 관리자 고르개에는 🌐 그룹이 아예 없다 ← 눌러서 실패하게 두지 않는다');
  ok(r.community_admin.choices.includes('g1'),
     '그래도 우리 공동체 그룹은 고를 수 있다');
  await pg.close();
}

// ── ④ 방에 들어가면 다른 공동체 사람 이름이 보인다 ────────────
console.log('\n④ 다른 공동체 사람의 이름');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.channel_groups = d.GROUPS;
    await loadChannelGroups();
    window.__DB['rpc:cross_channel_members'] = d.CAND;
    const crossCh = { id:'ch1', name:'연합모임방', kind:'topic', community_id:'c1', group_id:'g3' };
    const plainCh = { id:'ch2', name:'우리방',     kind:'topic', community_id:'c1', group_id:'g1' };
    const out = { crossIs: isCrossChannel(crossCh), plainIs: isCrossChannel(plainCh) };
    //  보통 방 — 아무것도 불러오지 않는다
    window.__rpc = [];
    await loadCrossChannelMembers(plainCh);
    out.plainCalls = window.__rpc.length;
    //  🌐 방 — 불러와서 members 에 섞는다
    window.__rpc = [];
    await loadCrossChannelMembers(crossCh);
    out.crossCalls = window.__rpc.length;
    out.b1 = members['b1'] ? { name: members['b1'].name, comm: members['b1'].community_name } : null;
    return out;
  }, { GROUPS, CAND });

  ok(r.crossIs, '🌐 그룹 안의 방을 🌐 방으로 알아본다');
  ok(!r.plainIs, '보통 방은 🌐 방이 아니다');
  ok(r.plainCalls === 0, '보통 방에서는 서버에 묻지도 않는다');
  ok(r.crossCalls === 1, '🌐 방에서만 그 방 사람들을 물어본다');
  ok(r.b1 && r.b1.name === '미국학생', '다른 공동체 사람의 이름이 들어온다');
  ok(r.b1 && r.b1.comm === 'IM USA', '어느 공동체 사람인지도 들어온다');
  await pg.close();
}

// ── ⑤ 그룹 만들기 — 세 갈래 ──────────────────────────────────
console.log('\n⑤ 그룹 만들기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (G) => {
    window.__DB.channel_groups = G;
    await loadChannelGroups();
    const out = {};
    //  총관리자 — 세 갈래 창
    ME.community_role = 'super_admin';
    await createChannelGroup();
    const m = document.querySelector('.group-kind-modal');
    out.modal = !!m;
    out.kinds = m ? [...m.querySelectorAll('[data-gk]')].map(x => x.dataset.gk) : [];
    out.txt = m ? m.innerText : '';
    //  🌐 를 골라 만들면 깃발이 간다
    document.getElementById('gk-name').value = '연합청년';
    pickGroupKind('cross');
    window.__ins = [];
    await submitGroupKind();
    out.sent = JSON.stringify(window.__ins);
    //  우리 공동체 그룹은 깃발이 없다
    await createChannelGroup();
    document.getElementById('gk-name').value = '찬양팀';
    pickGroupKind('comm');
    window.__ins = [];
    await submitGroupKind();
    out.sentComm = JSON.stringify(window.__ins);
    return out;
  }, GROUPS);

  ok(r.modal, '총관리자에게는 고르는 창이 뜬다');
  ok(r.kinds.join(',') === 'mine,comm,cross', '세 갈래가 다 있다');
  ok(/나만 보는 그룹/.test(r.txt) && /우리 공동체 그룹/.test(r.txt) && /모든 공동체 그룹/.test(r.txt),
     '세 갈래를 글로 갈라 놓았다');
  ok(/모든 공동체/.test(r.txt) && /어느 공동체 사람이든/.test(r.txt),
     '🌐 를 고르면 어떻게 되는지 적어 놓았다');
  ok(/"cross_community":true/.test(r.sent), '🌐 를 고르면 깃발이 간다');
  ok(/"name":"연합청년"/.test(r.sent), '이름도 간다');
  ok(!/cross_community/.test(r.sentComm),
     '우리 공동체 그룹은 깃발을 아예 보내지 않는다 ← 기본은 소속공동체만');
  await pg.close();
}

// ── ⑥ 🌐 그룹은 총관리자만 고치고 지운다 ──────────────────────
console.log('\n⑥ 🌐 그룹 고치기·지우기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((G) => {
    const cross = G.find(g => g.id === 'g3'), plain = G.find(g => g.id === 'g1');
    const out = {};
    for (const role of ['super_admin','community_admin']) {
      ME.community_role = role;
      out[role] = {
        cross: /renameChannelGroup/.test(groupHeaderHtml(cross, 3)),
        plain: /renameChannelGroup/.test(groupHeaderHtml(plain, 3)),
        badge: /data-cross-badge/.test(groupHeaderHtml(cross, 3)),
      };
    }
    return out;
  }, GROUPS);

  ok(r.super_admin.cross, '총관리자는 🌐 그룹을 고칠 수 있다');
  ok(!r.community_admin.cross,
     '공동체 관리자는 🌐 그룹을 못 고친다 ← 남의 공동체까지 걸린 그룹이다');
  ok(r.community_admin.plain, '그래도 우리 공동체 그룹은 고칠 수 있다');
  ok(r.super_admin.badge && r.community_admin.badge,
     '🌐 그룹에는 표가 붙어서 보통 그룹과 헛갈리지 않는다');
  await pg.close();
}

await b.close();
done();
})();
