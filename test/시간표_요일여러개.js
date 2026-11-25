//  🗓 개인 시간표 — 요일 여러 개를 한 번에
//
//  개선창 · 정은규 (IM HQ, 10/27):
//    「시간표 추가할때 요일 여러개를 선택해서 한번에 추가 가능하게
//      해주시면 좋을것같습니다. 감사합니다.」
//
//  전에는 요일이 <select> 하나였습니다. 월·수·금에 같은 수업이 있으면
//  똑같은 내용을 **세 번** 넣어야 했습니다.
//
//  ⚠️ 고치기(수정) 중에는 그대로 하나만 고릅니다 — 한 일정이 여러 요일이
//     될 수는 없습니다. 여러 개 고르기는 새로 추가할 때만 띄웁니다.
//
//  재는 것:
//   ① 추가할 때는 요일 칩이 나온다 (select 가 아니다)
//   ② 여러 개 골라 한 번에 넣으면 요일마다 한 줄씩 들어간다
//   ③ 내용·시간은 모든 줄에 똑같이 들어간다
//   ④ 요일을 하나는 남긴다 (다 끄지 못한다)
//   ⑤ 칩을 눌러도 적던 내용이 날아가지 않는다
//   ⑥ 고치기 중에는 select 하나로 돌아간다
const { launch, openApp, ok, done } = require('./_harness');

async function openTT(b) {
  const pg = await openApp(b, { as:'student' });
  await pg.evaluate(async () => {
    ME.id = 'me'; ME.name = '홍길동'; ME.community_id = 'c1';
    myTT = []; mttDays = [1]; mttKind = 'class'; ttSelectedId = null;
    window.__DB['student_timetables'] = [];
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    //  표를 다시 읽지 않게 (시험에서는 화면만 봅니다)
    initMyTimetable = async () => { renderMyTimetable(); };
    document.getElementById('mytt-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="mytt-main"></div>');
    renderMyTimetable();
  });
  await pg.waitForTimeout(300);
  return pg;
}

const fill = (pg, subject, place) => pg.evaluate(([s, p]) => {
  document.getElementById('mtt-start').value = '09:00';
  document.getElementById('mtt-end').value   = '10:30';
  document.getElementById('mtt-subject').value = s;
  document.getElementById('mtt-place').value   = p;
}, [subject, place]);

(async () => {
const b = await launch();

// ── ① 추가할 때는 칩 ───────────────────────────────────────
console.log('\n① 요일 고르는 모양');
{
  const pg = await openTT(b);
  const r = await pg.evaluate(() => {
    const chips = [...document.querySelectorAll('[data-mttday]')];
    return {
      chips: chips.map(c => c.textContent.trim()),
      noSelect: !document.getElementById('mtt-day'),
      on: chips.filter(c => /1d3a5f/.test(c.style.background.replace(/\s/g,'')) ||
                            c.style.background === 'rgb(29, 58, 95)').map(c => c.dataset.mttday),
    };
  });
  ok(r.chips.length === 7, '월~일 일곱 칩이 나온다', r.chips.join(''));
  ok(r.chips[0] === '월' && r.chips[6] === '일', '월요일부터 일요일 순서다', r.chips.join(''));
  ok(r.noSelect, '요일 <select> 는 추가할 때 안 쓴다');
  ok(r.on.length === 1 && r.on[0] === '1', '처음엔 월요일 하나만 켜져 있다', r.on.join(','));
  await pg.close();
}

// ── ②③ 여러 요일에 한 번에 ─────────────────────────────────
console.log('\n② 월·수·금 한 번에');
{
  const pg = await openTT(b);
  await fill(pg, '국어', '301호');
  const r = await pg.evaluate(async () => {
    mttToggleDay(3); mttToggleDay(5);          // 월 + 수 + 금
    const picked = mttDays.slice();
    await addMyTTEntry();
    await new Promise(r => setTimeout(r, 500));
    const ins = (window.__ins || []).filter(x => x.t === 'student_timetables');
    const rows = ins.flatMap(x => x.rows);
    return { picked, rows, toast: window.__toast.join('|') };
  });
  ok(r.picked.join(',') === '1,3,5', '월·수·금이 골라진다', r.picked.join(','));
  ok(r.rows.length === 3, '세 줄이 들어간다 (요일마다 하나)', r.rows.length);
  ok(r.rows.map(x => x.day).sort().join(',') === '1,3,5',
     '요일이 각각 1·3·5 다', r.rows.map(x => x.day).join(','));
  ok(r.rows.every(x => x.subject === '국어' && x.place === '301호'),
     '내용·장소가 세 줄 모두 같다', JSON.stringify(r.rows.map(x => [x.subject, x.place])));
  ok(r.rows.every(x => x.start_time === '09:00' && x.end_time === '10:30'),
     '시간도 세 줄 모두 같다', JSON.stringify(r.rows.map(x => x.start_time)));
  ok(r.rows.every(x => x.member_id === 'me'), '모두 내 것으로 들어간다');
  ok(/3개 요일에 추가됐어요/.test(r.toast), '몇 개 요일에 넣었는지 알려 준다', r.toast);
  await pg.close();
}

// ── ②-2 하나만 고르면 전과 같다 ────────────────────────────
console.log('\n②-2 하나만 고를 때');
{
  const pg = await openTT(b);
  await fill(pg, '수학', '');
  const r = await pg.evaluate(async () => {
    await addMyTTEntry();
    await new Promise(r => setTimeout(r, 400));
    const rows = (window.__ins || []).filter(x => x.t === 'student_timetables').flatMap(x => x.rows);
    return { rows, toast: window.__toast.join('|') };
  });
  ok(r.rows.length === 1 && r.rows[0].day === 1, '한 줄만 들어간다', r.rows.length);
  ok(/✅ 추가됐어요/.test(r.toast) && !/요일에/.test(r.toast),
     '하나일 때는 전과 같은 말이다', r.toast);
  await pg.close();
}

// ── ④ 마지막 하나는 남는다 ─────────────────────────────────
console.log('\n④ 다 끄려고 할 때');
{
  const pg = await openTT(b);
  const r = await pg.evaluate(() => {
    window.__toast = [];
    mttToggleDay(1);                 // 하나뿐인 것을 끄려고
    return { days: mttDays.slice(), toast: window.__toast.join('|') };
  });
  ok(r.days.join(',') === '1', '마지막 하나는 안 꺼진다', r.days.join(','));
  ok(/하나는 골라야/.test(r.toast), '하나는 골라야 한다고 말해 준다', r.toast);
  await pg.close();
}

// ── ⑤ 칩을 눌러도 적던 것이 남는다 ──────────────────────────
console.log('\n⑤ 적던 내용 지키기');
{
  const pg = await openTT(b);
  await fill(pg, '적던 과목', '적던 장소');
  const r = await pg.evaluate(() => {
    mttToggleDay(4);
    const chip = document.querySelector('[data-mttday="4"]');
    return {
      subject: document.getElementById('mtt-subject').value,
      place:   document.getElementById('mtt-place').value,
      start:   document.getElementById('mtt-start').value,
      chipOn:  chip.style.background === 'rgb(29, 58, 95)',
      days:    mttDays.slice(),
    };
  });
  ok(r.subject === '적던 과목', '적던 내용이 그대로 있다', r.subject);
  ok(r.place === '적던 장소',   '적던 장소도 그대로 있다', r.place);
  ok(r.start === '09:00',       '적던 시간도 그대로 있다', r.start);
  ok(r.chipOn,                  '누른 칩은 켜진 색으로 바뀐다', String(r.chipOn));
  ok(r.days.join(',') === '1,4','고른 요일이 늘어난다', r.days.join(','));
  await pg.close();
}

// ── ⑥ 고치기 중에는 select 하나 ─────────────────────────────
console.log('\n⑥ 고치는 중일 때');
{
  const pg = await openTT(b);
  const r = await pg.evaluate(() => {
    myTT = [{ id:'e1', member_id:'me', day:2, start_time:'13:00', end_time:'14:00',
              subject:'영어', place:'', color:'#2a5298', term:mttTerm }];
    ttSelectedId = 'e1';
    renderMyTimetable();
    const sel = document.getElementById('mtt-day');
    return { hasSelect: !!sel, value: sel ? sel.value : '',
             opts: sel ? sel.options.length : 0,
             noChips: !document.querySelector('[data-mttday]') };
  });
  ok(r.hasSelect, '고칠 때는 요일 <select> 로 돌아간다');
  ok(r.noChips,   '여러 개 고르는 칩은 안 보인다');
  ok(r.value === '2', '고르던 일정의 요일(화)이 맞게 들어 있다', r.value);
  ok(r.opts === 7, '일곱 요일 모두 고를 수 있다', r.opts);
  await pg.close();
}

await b.close();
done();
})();
