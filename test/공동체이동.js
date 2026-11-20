//  🏛️ 공동체 이동(무빙) 개선
//
//    "A 공동체 소속 학생이 다른 공동체나 미국이나 필리핀으로 무빙을 가기도 해.
//     이럴때 어떻게 옮겨?"  →  "무빙 쪽 먼저 고쳐줘"
//
//  옮기는 기능 자체는 전에도 있었습니다. 다만 "가입할 때 공동체를 잘못 고른
//  사람" 을 고치려고 만든 것이라, 진짜 무빙에는 구멍이 세 개 있었습니다.
//
//   ① 새 공동체 선생님이 이전 생기부를 못 봤습니다 (권한이 기록의 공동체 기준)
//   ② 예치금·용돈 잔액이 따라가지 않았습니다 (₩ 가 옛 공동체에 갇힘)
//   ③ 부총관리자는 아예 못 옮겼습니다 (총관리자 전용)
//
//  선교사님이 고르신 것
//   ① 생기부·출결·독서기록·활동후기만 **읽기로** 연다
//      (상담·보건·관찰·노트·기도제목은 열지 않는다)
//   ② 옮길 때 자동 정산 — 옛 공동체에서 빼고 새 공동체에 같은 통화로 넣는다
//
//  서버 쪽은 운영 DB 에서 사람 흉내로 미리 재 보았습니다 (전부 되돌렸습니다):
//   · 옮기기 전 B 교사가 보는 A 생기부 0건 → 옮긴 뒤 9건 ✅
//   · B 교사가 A 기록을 고친 줄 0줄 (읽기 전용) ✅
//   · 상관없는 제3 공동체 교사는 여전히 0건 ✅
//   · 평교사 ✅막힘 · 부총관리자→해외 ✅막힘 · 부총관리자→같은 묶음 ✅통과
//   · 정산: A 잔액 189,540 → 0, B 잔액 0 → 189,540 ✅
//
//  ★ 여기서 재는 것 — 화면입니다
//   ① 찾기 카드가 총관리자·부총관리자에게만 보인다
//   ② 이동 창 목록이 부총관리자에겐 자기 묶음만 (총관리자는 전부)
//   ③ 부총관리자에게만 "묶음 안에서만" 안내가 붙는다
//   ④ 부총관리자는 다른 부총관리자를 못 옮긴다 (단추 대신 안내)
//   ⑤ 확인창에 정산 · 읽게 되는 기록 · 남는 기록 세 덩이가 다 나온다
//   ⑥ '아니오' 를 누르면 진짜로 옮기지 않는다
const { launch, openApp, ok, done } = require('./_harness');

const COMMS = [
  { id:'c1', name:'프로토스',        kind:'community', color:'#1d3a5f', created_at:'2026-01-01T00:00:00Z' },
  { id:'c2', name:'어웨이크닝',      kind:'community', color:'#1d3a5f', created_at:'2026-01-02T00:00:00Z' },
  { id:'a1', name:'리뉴젠 아카데미', kind:'academy',   color:'#1d3a5f', created_at:'2026-01-03T00:00:00Z' },
  { id:'o1', name:'IM USA',          kind:'overseas',  color:'#1d3a5f', created_at:'2026-01-04T00:00:00Z' },
];

const PEOPLE = [
  { id:'stu',   name:'이지후', email:'jihu@example.com',  community_id:'c1', community_role:'student',    status:'approved' },
  { id:'vice2', name:'유은혜', email:'eunhye@example.com', community_id:'c2', community_role:'vice_admin', status:'approved' },
  { id:'sup',   name:'선교사', email:'super@example.com',  community_id:'c1', community_role:'super_admin', status:'approved' },
];

async function open(b, role) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(({ role, COMMS, PEOPLE }) => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1';
    ME.community_role = role; ME.email = 'nobody@example.com';
    window.__DB.communities = COMMS;
    window.__DB.members = PEOPLE;
    _moveCommCache = null;                 // 역할마다 다시 읽게 한다
    document.getElementById('move-comm-modal')?.remove();
    let box = document.getElementById('admin-content');
    if (!box) { document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
                box = document.getElementById('admin-content'); }
    box.innerHTML = moveSearchCardHtml();
  }, { role, COMMS, PEOPLE });
  return pg;
}

//  이동 창을 열고 읽는다
async function openModal(pg, who) {
  await pg.evaluate(async (id) => {
    document.getElementById('move-comm-modal')?.remove();
    await showMoveCommunityModal(id);
  }, who);
  await pg.waitForTimeout(250);
  return pg.evaluate(() => {
    const m = document.getElementById('move-comm-modal');
    if (!m) return null;
    return {
      txt: m.innerText,
      to: [...m.querySelectorAll('div[onclick]')]
            .map(x => x.getAttribute('onclick') || '')
            .filter(s => s.indexOf('doMoveCommunity') === 0)
            .map(s => (s.match(/'([^']+)'\s*\)\s*$/) || [])[1]),
    };
  });
}

(async () => {
  const b = await launch();

  // ──────────────────────────────────────────────────────────
  console.log('\n① 찾기 카드가 누구에게 보이나');
  {
    const seen = {};
    for (const role of ['teacher', 'community_admin', 'vice_admin', 'super_admin']) {
      const pg = await open(b, role);
      seen[role] = await pg.evaluate(() => (moveSearchCardHtml() || '').length > 0);
      await pg.close();
    }
    ok(seen.super_admin === true,  '총관리자에게 보인다', JSON.stringify(seen));
    ok(seen.vice_admin  === true,  '부총관리자에게 보인다', JSON.stringify(seen));
    ok(seen.community_admin === false, '공동체 관리자에겐 안 보인다', JSON.stringify(seen));
    ok(seen.teacher === false,     '교사에겐 안 보인다', JSON.stringify(seen));
  }

  // ──────────────────────────────────────────────────────────
  console.log('\n② 이동 창의 공동체 목록');
  {
    const pg = await open(b, 'vice_admin');
    const r = await openModal(pg, 'stu');
    ok(!!r, '부총관리자도 이동 창이 열린다');
    ok(r && r.to.length === 1 && r.to[0] === 'c2',
       '부총관리자는 자기 묶음(리뉴젠 공동체) 하나만 — 지금 있는 곳은 빼고', r && JSON.stringify(r.to));
    ok(r && r.to.indexOf('o1') < 0, 'IM USA(해외 묶음)는 목록에 없다', r && JSON.stringify(r.to));
    ok(r && r.to.indexOf('a1') < 0, '리뉴젠 아카데미도 목록에 없다', r && JSON.stringify(r.to));
    await pg.close();
  }
  {
    const pg = await open(b, 'super_admin');
    const r = await openModal(pg, 'stu');
    ok(r && r.to.length === 3, '총관리자는 c1 빼고 전부 (3곳)', r && JSON.stringify(r.to));
    ok(r && r.to.indexOf('o1') >= 0, '총관리자는 IM USA 로도 보낼 수 있다', r && JSON.stringify(r.to));
    await pg.close();
  }

  // ──────────────────────────────────────────────────────────
  console.log('\n③ 묶음 안내 문구');
  {
    const pg = await open(b, 'vice_admin');
    const r = await openModal(pg, 'stu');
    ok(r && /묶음 안에서만/.test(r.txt), '부총관리자에게 "묶음 안에서만" 안내가 붙는다', r && r.txt.slice(0,160));
    await pg.close();
  }
  {
    const pg = await open(b, 'super_admin');
    const r = await openModal(pg, 'stu');
    ok(r && !/묶음 안에서만/.test(r.txt), '총관리자에겐 그 안내가 없다', r && r.txt.slice(0,160));
    await pg.close();
  }

  // ──────────────────────────────────────────────────────────
  console.log('\n④ 부총관리자는 다른 부총관리자를 못 옮긴다');
  {
    const read = async (role) => {
      const pg = await open(b, role);
      const out = await pg.evaluate(async () => {
        const q = document.getElementById('mv-q');
        if (!q) return { txt:'(찾기 카드가 없음)', btns:-1 };   // 멈추지 말고 알린다
        q.value = '유은';
        await adminMemberSearch();
        await new Promise(r => setTimeout(r, 250));
        const box = document.getElementById('mv-results');
        return {
          txt: box.innerText,
          btns: [...box.querySelectorAll('button')]
                  .map(x => x.getAttribute('onclick') || '')
                  .filter(s => /showMoveCommunityModal/.test(s)).length,
        };
      });
      await pg.close();
      return out;
    };
    const v = await read('vice_admin');
    ok(v.btns === 0, '부총관리자 화면엔 이동 단추가 안 나온다', JSON.stringify(v));
    ok(/총관리자만/.test(v.txt), '대신 "총관리자만 옮깁니다" 라고 알려준다', v.txt.slice(0,200));

    const s = await read('super_admin');
    ok(s.btns === 1, '총관리자에겐 이동 단추가 그대로 있다', JSON.stringify(s));
  }

  // ──────────────────────────────────────────────────────────
  console.log('\n⑤ 확인창에 세 덩이가 다 나온다');
  {
    const pg = await open(b, 'super_admin');
    const out = await pg.evaluate(async () => {
      const calls = [];
      sb.rpc = (name, args) => {
        calls.push({ name, args });
        if (!args.p_dry_run) return Promise.resolve({ data:{ member_name:'이지후',
          from_community:'프로토스', to_community:'어웨이크닝', unlinked:{}, settle:[] }, error:null });
        return Promise.resolve({ data: {
          dry_run: true, member_name:'이지후',
          from_community:'프로토스', to_community:'어웨이크닝',
          readable:  { tcs_records: 9, attendance_daily: 120 },
          leftovers: { counseling_logs: 2, messages: 40 },
          settle: [ { kind:'예치금', currency:'원', amount: 189540 },
                    { kind:'용돈',   currency:'원', amount: -24900 } ],
        }, error:null });
      };
      let asked = '';
      window.confirm = (m) => { asked = m; return false; };   // 아니오
      await doMoveCommunity('stu', 'c2');
      return { asked, calls: calls.map(c => c.args.p_dry_run === true) };
    });

    ok(/189,540/.test(out.asked),  '예치금 잔액이 금액으로 나온다', out.asked);
    ok(/-24,900/.test(out.asked),  '마이너스인 용돈 잔액도 그대로 나온다', out.asked);
    ok(/자동으로 정산/.test(out.asked), '정산한다고 분명히 말한다', out.asked);
    ok(/생활기록부 9건/.test(out.asked),  '읽게 되는 생기부 건수가 나온다', out.asked);
    ok(/출결 120건/.test(out.asked),      '읽게 되는 출결 건수가 나온다', out.asked);
    ok(/읽기만/.test(out.asked),          '"읽기만" 이라고 못 박는다', out.asked);
    ok(/상담 기록 2건/.test(out.asked),   '안 보이게 남는 기록도 나온다', out.asked);
    ok(/안 보입니다/.test(out.asked),     '그건 안 보인다고 말한다', out.asked);

    // ⑥ 아니오 → 진짜 이동은 안 부른다
    ok(out.calls.length === 1 && out.calls[0] === true,
       '아니오를 누르면 미리보기 한 번만 부르고 끝난다', JSON.stringify(out.calls));
    await pg.close();
  }

  console.log('\n⑥ 예를 누르면 진짜로 옮긴다');
  {
    const pg = await open(b, 'super_admin');
    const out = await pg.evaluate(async () => {
      const calls = [];
      sb.rpc = (name, args) => {
        calls.push(args.p_dry_run === true);
        return Promise.resolve({ data:{ member_name:'이지후', from_community:'프로토스',
          to_community:'어웨이크닝', readable:{}, leftovers:{}, unlinked:{ 채널_참여: 3 },
          settle:[ { kind:'예치금', currency:'원', amount: 189540 } ] }, error:null });
      };
      window.confirm = () => true;
      let toast = '';
      showUploadToast = (m) => { toast = m; };
      await doMoveCommunity('stu', 'c2');
      return { calls, toast };
    });
    ok(out.calls.length === 2 && out.calls[0] === true && out.calls[1] === false,
       '미리보기 한 번, 진짜 이동 한 번', JSON.stringify(out.calls));
    ok(/189,540/.test(out.toast), '끝난 뒤 알림에도 정산 금액이 나온다', out.toast);
    await pg.close();
  }

  await b.close();
  done();
})();
