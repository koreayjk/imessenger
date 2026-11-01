//  👤 부총관리자 — 자기 공동체에선 관리자와 똑같이, 남의 공동체는 눈으로만
//
//  ① 화면 — 관리자 페이지의 역할 칸
//     목록에 'vice_admin' 칸이 없는 채로 <select> 를 그리면 브라우저가
//     맨 앞(학생)을 고른 것처럼 보여 줍니다. 그래서 부총관리자 Clara 가
//     **학생으로 보였습니다.** 건드리면 RLS 가 막아 주지만, 화면이 거짓말을
//     하고 있었습니다.
//
//  ② 설치 SQL — 같은 자리를 세 번째 고치는 중이라 글로 못 박습니다.
//     members_update 안에 손으로 끼워 넣은 '부총관리자' 한 줄은, 뒤에 깐
//     설치 파일이 같은 이름으로 정책을 다시 만들 때마다 조용히 사라졌습니다
//     (허용 정책은 이름이 같으면 통째로 덮어쓰입니다).
//     그래서 이번엔 can_admin_members() 자체에 넣고, 공동체 울타리는
//     **이름이 다른 제한 정책**으로 따로 세웁니다.
const fs = require('fs'), path = require('path');
const { launch, openApp, ok, done } = require('./_harness');

const SQL = fs.readFileSync(path.join(__dirname, '..', 'db', '부총관리자_권한_DB설치.sql'), 'utf8')
              .replace(/--[^\n]*/g, '');          //  주석에 적힌 글자에 속지 않는다

(async () => {
const b = await launch();

// ── ① 화면 — 역할 칸 ─────────────────────────────────────────
console.log('\n① 관리자 페이지의 역할 칸');
{
  const pg = await openApp(b, { as: 'teacher' });   // 김선생 = community_admin
  const r = await pg.evaluate(async () => {
    window.__DB = window.__DB || {};
    window.__DB.members = [
      { id:'me', name:'김선생', community_id:'c1', community_role:'community_admin', status:'approved' },
      { id:'vz', name:'Clara',  community_id:'c1', community_role:'vice_admin',      status:'approved' },
      { id:'sa', name:'총관리', community_id:'c1', community_role:'super_admin',     status:'approved' },
      { id:'st', name:'홍길동', community_id:'c1', community_role:'student',         status:'approved' },
    ];
    await renderAdminMembers();
    const rows = [...document.querySelectorAll('#admin-content .adm-row')];
    const find = (nm) => rows.find(x => x.textContent.includes(nm));
    const look = (nm) => {
      const row = find(nm); if (!row) return null;
      const sel = row.querySelector('select[onchange^="changeMemberCommunityRole"]');
      return {
        있나: !!row,
        고를수있나: !!sel,
        고른값: sel ? sel.value : null,
        자물쇠: /🔒/.test(row.textContent),
        글자: row.textContent.replace(/\s+/g, ' ').trim(),
        탈퇴: !!row.querySelector('button[onclick^="deleteMember"]'),
      };
    };
    return { vice: look('Clara'), student: look('홍길동'), superA: look('총관리') };
  });

  ok(!!r.vice, '부총관리자 줄이 그려진다');
  ok(r.vice && r.vice.고를수있나 === false,
     '관리자가 볼 때 부총관리자의 역할 칸은 고를 수 없다 (칸이 없어 학생으로 보이던 자리)');
  ok(r.vice && r.vice.자물쇠 === true, '대신 🔒 가 붙는다');
  ok(r.vice && /부총관리자|Deputy/.test(r.vice.글자), '글자도 부총관리자라고 나온다');
  ok(r.vice && r.vice.탈퇴 === false, '관리자는 부총관리자를 탈퇴시킬 수 없다 (RLS 도 막지만 버튼부터 없앤다)');
  ok(r.superA && r.superA.고를수있나 === false, '총관리자는 전처럼 그대로 잠겨 있다');
  ok(r.student && r.student.고를수있나 === true, '학생 역할은 전처럼 고칠 수 있다');
  ok(r.student && r.student.고른값 === 'student', '학생 칸은 학생이 골라져 있다');
  await pg.close();
}

// ── ② 설치 SQL ───────────────────────────────────────────────
console.log('\n② db/부총관리자_권한_DB설치.sql');

//  can_admin_members() 몸통만 떼어 본다
const camStart = SQL.indexOf('function public.can_admin_members()');
const cam = camStart > 0 ? SQL.slice(camStart, SQL.indexOf('$$;', camStart)) : '';
ok(/vice_admin/.test(cam),
   'can_admin_members() 안에 부총관리자가 들어 있다 (승인·거절·역할변경·탈퇴가 전부 여기 달려 있다)');
ok(/super_admin/.test(cam) && /community_admin/.test(cam),
   '총관리자·관리자는 그대로 있다');

//  공동체 울타리 — 이름이 달라야 다음 설치 파일에 덮어쓰이지 않는다
ok(/_vice_comm_ins/.test(SQL) && /_vice_comm_upd/.test(SQL) && /_vice_comm_del/.test(SQL),
   '쓰기 울타리를 insert·update·delete 세 군데 다 세운다');
ok(/as restrictive/.test(SQL), '울타리는 제한(restrictive) 정책이다 — 허용 정책과 AND 로 묶인다');
ok(!/_vice_comm_sel/.test(SQL) && !/restrictive for select to authenticated\s*\n?\s*using \(\(not public\.is_vice_admin/.test(SQL),
   '읽기에는 울타리를 걸지 않는다 (남의 공동체를 눈으로는 봐야 한다)');
ok(/community_id = public\.my_community_id\(\)/.test(SQL), '울타리 조건은 내 공동체인가이다');
ok(/or community_id is null/.test(SQL), '공동체가 비어 있는 행은 통과시킨다');

//  당사자 예외가 없으면 남의 공동체에서 걸려 온 전화를 받지도 못한다
ok(/'caller_id','callee_id'/.test(SQL) || /caller_id/.test(SQL) && /callee_id/.test(SQL),
   '내가 당사자인 행(건 사람·받은 사람…)은 예외로 둔다 — 없으면 전화를 못 받는다');

//  community_id 가 없는 표는 울타리가 닿지 않는다. 따로 묶어야 한다.
ok(/drop policy if exists student_parents_write/.test(SQL) &&
   /member_community_of\(student_id\) = public\.my_community_id\(\)/.test(SQL),
   '학생–보호자 묶기는 community_id 칸이 없어 따로 묶는다');

//  넣는 쪽 구멍
ok(/members_protect_superadmin_ins/.test(SQL),
   '총·부총관리자 행을 새로 꽂아 넣는 것도 막는다 (고치는 쪽만 막혀 있었다)');

//  저장용량 지우기
const delStart = SQL.indexOf('function public.can_delete_storage_file');
const del = delStart > 0 ? SQL.slice(delStart, SQL.indexOf('$$;', delStart)) : '';
ok(/me\.community_role = 'super_admin'/.test(del) && !/in \('super_admin','vice_admin'\)\s*$/m.test(del),
   '파일 지우기는 부총관리자도 자기 공동체만 (전에는 어디든 지울 수 있었다)');

//  재실행 안전
const creates = (SQL.match(/create policy/g) || []).length;
const drops   = (SQL.match(/drop policy if exists/g) || []).length;
ok(drops >= creates, '만드는 정책마다 먼저 지운다 — 다시 돌려도 안전하다 (' + drops + ' ≥ ' + creates + ')');

await b.close();
done();
})();
