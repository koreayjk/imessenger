// 🔒 학부모 권한 — 1:1 은 교직원에게만 · 방 운영은 안 한다 · 역할 칸에 학부모가 있다
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();

// ── ① 누구와 1:1 을 틀 수 있나 ────────────────────────────────
console.log('\n① 누구와 1:1 을 틀 수 있나');
{ const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(() => {
    const by = {}; Object.values(members).forEach(m => { by[m.id] = canDmMember(m); });
    return by;
  });
  ok(r['me'] === true,  '학부모 → 관리자(김선생) 됩니다');
  ok(r['t2'] === true,  '학부모 → 교사(박교사) 됩니다');
  ok(r['s1'] === false, '학부모 → 학생 막힙니다 — 자기 아이라도');
  ok(r['s2'] === false, '학부모 → 남의 집 아이 막힙니다');
  await pg.close(); }

{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => ({ toParent: canDmMember(members['p1']), toStudent: canDmMember(members['s1']) }));
  ok(r.toParent  === true, '교직원 → 학부모 는 그대로 됩니다 (피드백 링크를 보내야 하니까)');
  ok(r.toStudent === true, '교직원 → 학생 도 그대로 됩니다');
  await pg.close(); }

{ const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(() => ({
    toParent: canDmMember(members['p1']), toTeacher: canDmMember(members['t2']), toStudent: canDmMember(members['s2']),
  }));
  ok(r.toParent  === false, '학생 → 학부모 도 막힙니다 — 한쪽만 막으면 반대로 뚫립니다');
  ok(r.toTeacher === true,  '학생 → 교사 는 그대로 됩니다');
  ok(r.toStudent === false, '학생 → 학생 은 예전처럼 막힙니다');
  await pg.close(); }

// ── ② 1:1 고르는 창 ───────────────────────────────────────────
console.log('\n② 1:1 고르는 창');
{ const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(() => {
    showAddChannelModal();
    return { ids: [...document.querySelectorAll('#dm-member-list [data-mid]')].map(x => x.dataset.mid),
             topicTab: document.getElementById('add-tab-topic').style.display };
  });
  ok(r.ids.includes('me') && r.ids.includes('t2'), '선생님·관리자는 목록에 있습니다');
  ok(!r.ids.some(i => /^s\d$/.test(i)), '학생은 목록에서 아예 빠집니다');
  ok(r.topicTab === 'none', '학부모에게는 단체방 만들기 탭이 없습니다');
  await pg.close(); }

// ── ③ 방 운영(📢 공지 · 📋 제출 현황 · 투표 선택지) ───────────
console.log('\n③ 방 운영은 학생·학부모가 하지 않는다');
{ const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(() => {
    const out = { asParent: canManageAnnounce() };
    ME.community_role = 'student';       out.student = canManageAnnounce();
    ME.community_role = 'staff';         out.staff   = canManageAnnounce();
    ME.community_role = 'admin_officer'; out.officer = canManageAnnounce();
    ME.community_role = 'parent';
    const m = { id:'m1', channel_id:'ch2', sender_id:'t2', sender_name:'박교사',
                text:'안녕하세요', kind:'text', created_at:new Date().toISOString() };
    out.menu = msgActions(m).map(a => a.k);
    return out;
  });
  ok(r.asParent === false, '학부모에게는 공지·제출 현황 권한이 없습니다 (서버가 막던 것)');
  ok(r.student  === false, '학생도 그대로 막혀 있습니다');
  ok(r.staff    === true,  '간사는 그대로 됩니다');
  ok(r.officer  === true,  '행정담당자도 그대로 됩니다');
  ok(!r.menu.includes('announce'), "학부모의 메시지 메뉴에 '공지로 등록' 이 없습니다");
  ok(r.menu.includes('book'), '북마크 같은 보통 메뉴는 그대로 — 다 막아버린 게 아닙니다');
  await pg.close(); }

// ── ④ 관리자 화면의 역할 칸 ───────────────────────────────────
console.log('\n④ 관리자 → 멤버 관리의 역할 칸');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.community_role = 'super_admin';
    members['ao'] = { id:'ao', community_id:'c1', community_role:'admin_officer', name:'행정샘', status:'approved' };
    window.__DB.members = Object.values(members).map(m => ({ ...m, status:'approved' }));
    rolesGuideOpen = true;
    setMode('admin');
    await renderAdminMembers();
    await new Promise(r => setTimeout(r, 400));
    const main = document.getElementById('admin-content');
    const sels = [...main.querySelectorAll('select[onchange*="changeMemberCommunityRole"]')];
    const mine = sels.find(s => (s.getAttribute('onchange')||'').includes("'p1'"));
    return {
      vals: mine ? [...mine.options].map(o => o.value) : null,
      shown: mine && mine.options[mine.selectedIndex] ? mine.options[mine.selectedIndex].value : null,
      th: [...main.querySelectorAll('table thead th')].map(x => x.textContent.trim()),
      body: [...main.querySelectorAll('table tbody tr')].map(tr => [...tr.children].map(td => td.textContent.trim())),
      text: main.innerText,
    };
  });
  ok(r.vals && r.vals.includes('parent'), "역할 칸에 'parent' 가 있습니다");
  ok(r.shown === 'parent', '학부모는 학부모로 보입니다 — 없으면 브라우저가 첫 항목(학생)을 고른 것처럼 보여 줍니다');
  ok(r.vals && r.vals.indexOf('parent') === r.vals.indexOf('student') + 1, '학생 바로 다음에 놓입니다');
  ok(r.th.includes('학부모'), '권한 안내표에 학부모 열이 있습니다');
  { const col = r.th.indexOf('학부모');
    const row = r.body.find(c => /내 아이/.test(c[0] || ''));
    ok(!!row, "안내표에 '내 아이' 줄이 있습니다");
    ok(row && row[col] === '✓', "'내 아이' 는 학부모 칸에 ✓ 가 찍힙니다");
    ok(row && row.filter(c => c === '✓').length === 1, "'내 아이' 는 학부모만 — 다른 칸은 비어 있습니다"); }
  ok(/행정샘/.test(r.text), '행정담당자도 목록에 나옵니다 (없으면 아래 확인이 거짓으로 통과합니다)');
  ok(!/admin_officer/.test(r.text), "뱃지에 'admin_officer' 라는 영어가 날것으로 찍히지 않습니다");
  await pg.close(); }

// ── ⑤ '내 아이' 의 용돈기입장 ─────────────────────────────────
console.log("\n⑤ '내 아이' 의 🐷 용돈기입장");
{ const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(async () => {
    Object.assign(window.__DB, {
      allowance_entries: [
        { id:'a1', member_id:'s1', community_id:'c1', date:'2026-10-02', type:'income',  category:'용돈', memo:'10월 용돈', amount:50000, currency:'원' },
        { id:'a2', member_id:'s1', community_id:'c1', date:'2026-10-09', type:'expense', category:'간식', memo:'아이스크림', amount:3000,  currency:'원' },
        { id:'a3', member_id:'s1', community_id:'c1', date:'2026-10-14', type:'expense', category:'문구', memo:'볼펜',      amount:2500,  currency:'원' },
      ],
      deposit_entries: [], store_sales: [], tuition_bills: [], cert_requests: [], weekly_feedbacks: [],
    });
    childList = [{ id:'s1', name:'홍길동', community_id:'c1' }]; childPicked = 's1';
    await renderChildPage();
    await new Promise(r => setTimeout(r, 350));
    const m = document.getElementById('child-main');
    return { txt: m.innerText,
             btns: [...m.querySelectorAll('button')].map(x => x.getAttribute('onclick') || '') };
  });
  ok(/용돈기입장/.test(r.txt), '🐷 용돈기입장 칸이 있습니다');
  ok(/44,500/.test(r.txt), '남은 용돈을 더해서 보여줍니다 (50,000 − 5,500)');
  ok(/아이스크림/.test(r.txt) && /볼펜/.test(r.txt), '아이가 적은 내용이 그대로 보입니다');
  ok(r.btns.filter(x => /allowance|finAdd|finSave/i.test(x)).length === 0, '학부모 화면에는 용돈을 고치는 단추가 없습니다');
  ok(r.txt.indexOf('예치금') < r.txt.indexOf('용돈기입장'), '예치금 다음에 용돈이 옵니다');
  await pg.close(); }

await b.close();
done();
})();
