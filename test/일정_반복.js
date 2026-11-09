//  🔁 일정 반복 — 구글 캘린더 반복 일정 연동 (개선창 ⑭ · 박윤환 · RM · 11/06)
//
//    "일정에서, 구글 캘린더에 반복으로 설정한 내용이 TCS와 연동되지 않고,
//     최초로 기록한 일정만 서로 동기화 되는 부분을 개선 부탁드립니다."
//
//  맞는 말씀이었습니다. gcal-sync 가 일부러 `singleEvents: false` 로 두고
//  **대표 일정 한 건만** 들여오면서 설명에 '🔁 매주 …' 라는 글만 적어
//  뒀습니다 — events 표에 '반복' 개념이 아예 없었기 때문입니다.
//
//  고친 방향 : 줄을 늘리지 않고 규칙(RRULE) 을 담고, 달력이 그릴 때 펼친다.
//
//  ★ 여기서 재는 것
//   ① 규칙을 날짜로 펼치는 셈이 맞나 (가지마다)
//   ② 달력이 실제로 네 번 그리나 (한 번이 아니라)
//   ③ 회차를 눌러도 대표 일정이 열리나
//   ④ 구글에서 그 회차만 지운 날은 빠지나
//   ⑤ 고르개가 만든 규칙이 그대로 저장되나 / 복잡한 규칙을 망치지 않나
//   ⑥ 시간대가 달라도 '오늘' 이 하루 밀리지 않나
const { launch, openApp, ok, done } = require('./_harness');

//  2026-11 : 1일(일) 2월 3화 4수 5목 6금 7토 8일 9월 … 30월
const WED = { id:'E-wed', title:'수요 예배', start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE',
              rrule_except:[], color:'#4285F4', community_id:'c1', created_by:'me', owner_id:null };
const ONE = { id:'E-one', title:'한 번 행사', start_date:'2026-11-12',
              rrule:null, rrule_except:[], color:'#2a5298', community_id:'c1', created_by:'me', owner_id:null };

async function openCal(b, o = {}) {
  const pg = await openApp(b, Object.assign({}, o.tz ? { tz:o.tz } : {}));
  await pg.evaluate((d) => {
    ME.community_role = 'community_admin'; ME.community_id = 'c1'; ME.id = 'me';
    calEvents = (d.EVS || []).map(x => Object.assign({}, x));
    calBirthdays = []; calCatFilter = null;
    calYear = 2026; calMonth = 10;        // 0=1월 → 10=11월
    calSelectedDate = d.pick || null;
    window.__DB.events = calEvents.map(x => Object.assign({}, x));
    renderCalendar();
  }, { EVS: o.evs || [WED, ONE], pick: o.pick || null });
  return pg;
}

(async () => {
const b = await launch();

// ── ① 규칙을 날짜로 펼치는 셈 ──────────────────────────────
console.log('\n① 규칙을 날짜로 펼치는 셈');
{
  const pg = await openCal(b);
  const r = await pg.evaluate(() => {
    const T = (ev, a, z) => rrOccurrences(ev, a, z).join(',');
    return {
      wed:      T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE' }, '2026-11-01', '2026-11-30'),
      noByday:  T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY' }, '2026-11-01', '2026-11-30'),
      biweek:   T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;INTERVAL=2;BYDAY=WE' }, '2026-11-01', '2026-12-31'),
      weekday:  T({ start_date:'2026-11-02', rrule:'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR' }, '2026-11-02', '2026-11-08'),
      daily:    T({ start_date:'2026-11-09', rrule:'FREQ=DAILY' }, '2026-11-09', '2026-11-13'),
      every3:   T({ start_date:'2026-11-09', rrule:'FREQ=DAILY;INTERVAL=3' }, '2026-11-09', '2026-11-20'),
      count3:   T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE;COUNT=3' }, '2026-11-01', '2026-12-31'),
      until:    T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE;UNTIL=20261118T000000Z' }, '2026-11-01', '2026-12-31'),
      monthly:  T({ start_date:'2026-11-09', rrule:'FREQ=MONTHLY' }, '2026-11-01', '2027-02-28'),
      third:    T({ start_date:'2026-11-18', rrule:'FREQ=MONTHLY;BYDAY=3WE' }, '2026-11-01', '2027-01-31'),
      lastFri:  T({ start_date:'2026-11-27', rrule:'FREQ=MONTHLY;BYDAY=-1FR' }, '2026-11-01', '2027-01-31'),
      day31:    T({ start_date:'2026-01-31', rrule:'FREQ=MONTHLY;BYMONTHDAY=31' }, '2026-01-01', '2026-05-31'),
      yearly:   T({ start_date:'2026-11-09', rrule:'FREQ=YEARLY' }, '2026-01-01', '2029-12-31'),
      except:   T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE', rrule_except:['2026-11-11'] }, '2026-11-01', '2026-11-30'),
      countWin: T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE;COUNT=3' }, '2026-11-15', '2026-12-31'),
      before:   T({ start_date:'2026-11-04', rrule:'FREQ=WEEKLY;BYDAY=WE' }, '2026-09-01', '2026-10-31'),
      none:     T({ start_date:'2026-11-04' }, '2026-11-01', '2026-11-30'),
      bogus:    T({ start_date:'2026-11-04', rrule:'FREQ=HOURLY' }, '2026-11-01', '2026-11-30'),
    };
  });
  await pg.close();
  ok(r.wed === '2026-11-04,2026-11-11,2026-11-18,2026-11-25', '매주 수요일 → 11월에 4번');
  ok(r.noByday === r.wed, 'BYDAY 가 없으면 시작한 요일로 매주');
  ok(r.biweek === '2026-11-04,2026-11-18,2026-12-02,2026-12-16,2026-12-30', '격주 — 달을 넘어가도 간격이 유지된다');
  ok(r.weekday === '2026-11-02,2026-11-03,2026-11-04,2026-11-05,2026-11-06', '주중 매일 (월~금) — 토·일은 빠진다');
  ok(r.daily === '2026-11-09,2026-11-10,2026-11-11,2026-11-12,2026-11-13', '매일');
  ok(r.every3 === '2026-11-09,2026-11-12,2026-11-15,2026-11-18', '3일마다');
  ok(r.count3 === '2026-11-04,2026-11-11,2026-11-18', 'COUNT=3 — 세 번만');
  ok(r.until === '2026-11-04,2026-11-11,2026-11-18', 'UNTIL — 그 날까지');
  ok(r.monthly === '2026-11-09,2026-12-09,2027-01-09,2027-02-09', '매월 같은 날');
  ok(r.third === '2026-11-18,2026-12-16,2027-01-20', '매월 셋째 수요일');
  ok(r.lastFri === '2026-11-27,2026-12-25,2027-01-29', '매월 마지막 금요일');
  ok(r.day31 === '2026-01-31,2026-03-31,2026-05-31', '매월 31일 — 없는 달은 건너뛴다 (2·4월)');
  ok(r.yearly === '2026-11-09,2027-11-09,2028-11-09,2029-11-09', '매년');
  ok(r.except === '2026-11-04,2026-11-18,2026-11-25', '그 회차만 지운 날은 빠진다');
  ok(r.countWin === '2026-11-18', 'COUNT 은 창 앞쪽 회차도 세어야 맞다');
  ok(r.before === '', '시작 전에는 아무것도 없다');
  ok(r.none === '' && r.bogus === '', '반복이 아니거나 모르는 규칙은 펼치지 않는다');
}

// ── ② 달력이 진짜 네 번 그리나 ────────────────────────────
console.log('\n② 달력이 네 번 그린다 — 전에는 한 번이었습니다');
{
  const pg = await openCal(b);
  const r = await pg.evaluate(() => {
    const g = document.getElementById('cal-grid').innerHTML;
    const hits = g.match(/editEvent\('rr:E-wed:[0-9-]+'\)/g) || [];
    return {
      days: hits.map(x => x.match(/:(\d{4}-\d{2}-\d{2})/)[1]).sort(),
      plain: (g.match(/editEvent\('E-one'\)/g) || []).length,
      raw: (g.match(/editEvent\('E-wed'\)/g) || []).length,
    };
  });
  await pg.close();
  ok(r.days.join(',') === '2026-11-04,2026-11-11,2026-11-18,2026-11-25',
     '11월 달력에 수요 예배가 4번 그려진다 (' + r.days.length + '번)');
  ok(r.raw === 0, '대표 일정이 날것으로 한 번 더 그려지지 않는다 (겹치지 않는다)');
  ok(r.plain === 1, '반복 아닌 일정은 그대로 한 번');
}
{
  //  달을 넘겨도 그 달 것만
  const pg = await openCal(b);
  const r = await pg.evaluate(() => {
    calMonth = 11;                       // 12월
    renderCalendar();
    const g = document.getElementById('cal-grid').innerHTML;
    return (g.match(/editEvent\('rr:E-wed:[0-9-]+'\)/g) || [])
      .map(x => x.match(/:(\d{4}-\d{2}-\d{2})/)[1]).sort();
  });
  await pg.close();
  ok(r.join(',') === '2026-12-02,2026-12-09,2026-12-16,2026-12-23,2026-12-30',
     '12월로 넘기면 12월의 수요일 5번 (' + r.length + '번)');
}

// ── ③ 날짜를 누르면 그 날 목록에도 보인다 ─────────────────
console.log('\n③ 그 날 목록');
{
  const pg = await openCal(b, { pick:'2026-11-18' });
  const r = await pg.evaluate(() => {
    showDayEvents('2026-11-18');
    const a = document.getElementById('cal-events');
    return { txt: a.textContent, ids: (a.innerHTML.match(/editEvent\('([^']+)'\)/g) || []) };
  });
  await pg.close();
  ok(/수요 예배/.test(r.txt), '11/18 목록에 수요 예배가 있다 (대표 날짜가 아닌 날)');
  ok(r.ids.join('|').includes('rr:E-wed:2026-11-18'), '그 회차로 이어진다');
}

// ── ④ 회차를 눌러도 대표 일정이 열린다 ───────────────────
console.log('\n④ 회차를 눌러도 대표가 열린다');
{
  const pg = await openCal(b);
  const r = await pg.evaluate(() => {
    editEvent('rr:E-wed:2026-11-18');
    return {
      open: document.getElementById('event-modal').style.display,
      id: editingEventId,
      title: document.getElementById('ev-title').value,
      date: document.getElementById('ev-date').value,
      rep: document.getElementById('ev-rep').value,
      note: document.getElementById('ev-rep-note').textContent,
      real: rrRealId('rr:E-wed:2026-11-18'),
      plainReal: rrRealId('E-one'),
    };
  });
  await pg.close();
  ok(r.open === 'flex' && r.id === 'E-wed', '대표 일정(E-wed)이 열린다');
  ok(r.title === '수요 예배' && r.date === '2026-11-04', '대표의 내용과 첫 회차 날짜가 들어온다');
  ok(r.rep === 'WEEKLY', "반복 고르개가 '매주' 로 맞춰진다");
  ok(/매주/.test(r.note) && /모든 회차/.test(r.note),
     '고치면 모든 회차에 반영된다고 미리 말해준다');
  ok(r.real === 'E-wed' && r.plainReal === 'E-one', '가짜 id 에서 대표 id 를 바르게 뽑는다');
}

// ── ⑤ 고르개 → 규칙 ─────────────────────────────────────
console.log('\n⑤ 고르개가 만드는 규칙');
{
  const pg = await openCal(b);
  const r = await pg.evaluate(() => {
    const out = {};
    const set = (v, until) => {
      document.getElementById('ev-rep').value = v;
      document.getElementById('ev-rep-until').value = until || '';
      onEvRepChange();
      return evRruleFromUi();
    };
    document.getElementById('ev-date').value = '2026-11-04';   // 수요일
    out.none = set('');
    out.daily = set('DAILY');
    out.weekly = set('WEEKLY');
    out.weekday = set('WEEKDAY');
    out.monthly = set('MONTHLY');
    out.yearly = set('YEARLY');
    out.untilled = set('WEEKLY', '2026-12-31');
    //  ★ 구글에서 들어온 복잡한 규칙을 고르개가 망치지 않는가
    evSetRepeatUi('FREQ=WEEKLY;INTERVAL=3;BYDAY=TU,TH');
    out.keepSel = document.getElementById('ev-rep').value;
    out.keepRule = evRruleFromUi();
    out.keepNote = document.getElementById('ev-rep-note').textContent;
    //  그 상태에서 '매일' 로 바꾸면 새 규칙이 나와야 한다
    out.changed = set('DAILY');
    return out;
  });
  await pg.close();
  ok(r.none === null, "'반복 안 함' 은 빈 값");
  ok(r.daily === 'FREQ=DAILY', '매일');
  ok(r.weekly === 'FREQ=WEEKLY;BYDAY=WE', '매주 — 그 날 요일(수)을 넣는다');
  ok(r.weekday === 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', '주중 매일');
  ok(r.monthly === 'FREQ=MONTHLY' && r.yearly === 'FREQ=YEARLY', '매월 · 매년');
  ok(r.untilled === 'FREQ=WEEKLY;BYDAY=WE;UNTIL=20261231T235959Z', '끝나는 날을 넣으면 UNTIL 이 붙는다');
  ok(r.keepSel === 'KEEP', "고르개로 못 담는 규칙은 '지금 규칙 그대로'");
  ok(r.keepRule === 'FREQ=WEEKLY;INTERVAL=3;BYDAY=TU,TH',
     '★ 손대지 않으면 원래 규칙을 그대로 둔다 ← 안 그러면 사용자가 안 건드린 반복이 바뀐다');
  ok(/3주마다/.test(r.keepNote), '그 규칙을 사람 말로 보여준다');
  ok(r.changed === 'FREQ=DAILY', '일부러 바꾸면 새 규칙이 나온다');
}

// ── ⑥ 저장 ──────────────────────────────────────────────
console.log('\n⑥ 저장');
{
  const pg = await openCal(b);
  const r = await pg.evaluate(async () => {
    showEventForm('2026-11-04');
    document.getElementById('ev-title').value = '수요 예배';
    document.getElementById('ev-rep').value = 'WEEKLY';
    onEvRepChange();
    const before = window.__ins.length;
    await submitEvent();
    const row = (window.__ins[before] || { rows:[{}] }).rows[0];
    return { rrule: row.rrule, title: row.title, start: row.start_date };
  });
  await pg.close();
  ok(r.title === '수요 예배' && r.start === '2026-11-04', '일정이 들어간다');
  ok(r.rrule === 'FREQ=WEEKLY;BYDAY=WE', '반복 규칙도 같이 들어간다');
}
{
  //  반복 칸이 아직 없는 DB — 반복만 빼고 저장하고, 솔직히 알려준다
  const pg = await openCal(b);
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    showEventForm('2026-11-04');
    document.getElementById('ev-title').value = '수요 예배';
    document.getElementById('ev-rep').value = 'WEEKLY';
    onEvRepChange();
    window.__err = { table:'events', times:1,
      e:{ message:`column events.rrule does not exist` } };
    const before = window.__ins.length;
    await submitEvent();
    const row = (window.__ins[before] || { rows:[{}] }).rows[0];
    return { said, has: 'rrule' in row, title: row.title };
  });
  await pg.close();
  ok(r.title === '수요 예배', '칸이 없어도 일정 자체는 저장된다');
  ok(!r.has, '반복만 빼고 보낸다');
  ok(/일정_반복_DB설치/.test(r.said), '무엇을 돌려야 하는지 알려준다');
  ok(/반복은 빼고/.test(r.said), "'반복까지 저장했다' 고 거짓말하지 않는다");
}

// ── ⑦ 시간대 — '오늘' 이 하루 밀리지 않는다 ─────────────
//  new Date().toISOString() 으로 '오늘' 을 만들면 UTC 로 밀려서, 한국에서는
//  새벽에 '어제' 가, 미국에서는 저녁에 '내일' 이 나옵니다. 일정·독후감 날짜가
//  하루 어긋납니다. UTC 컨테이너에서만 돌리면 안 드러나니 시간대를 옮겨서,
//  그리고 **덫이 실제로 걸려 있는지까지** 확인하고 잽니다.
console.log("\n⑦ 시간대 — '오늘' 이 안 밀린다");
{
  for (const tz of ['Asia/Seoul', 'America/Los_Angeles']) {
    const pg = await openCal(b, { tz });
    const r = await pg.evaluate(() => {
      const dawn = new Date(2026, 10, 9, 0, 30);    // 그 사람 시계로 11/9 새벽
      const nite = new Date(2026, 10, 9, 23, 30);   // 그 사람 시계로 11/9 밤
      calSelectedDate = null;
      showEventForm();                               // 날짜를 안 주고 열면 '오늘'
      return {
        dawn: ymdStr(dawn), dawnUtc: dawn.toISOString().slice(0, 10),
        nite: ymdStr(nite), niteUtc: nite.toISOString().slice(0, 10),
        today: todayStr(),
        formDate: document.getElementById('ev-date').value,
        off: new Date().getTimezoneOffset(),
      };
    });
    await pg.close();
    ok(r.off !== 0, `${tz} — 시간대가 실제로 옮겨졌다 (UTC 와 ${r.off}분 차이)`);
    ok(r.dawnUtc !== '2026-11-09' || r.niteUtc !== '2026-11-09',
       `${tz} — 덫이 걸려 있다 (toISOString 은 ${r.dawnUtc} / ${r.niteUtc})`);
    ok(r.dawn === '2026-11-09' && r.nite === '2026-11-09',
       `${tz} — 새벽도 밤도 그 날 그대로`);
    ok(r.formDate === r.today,
       `${tz} — 일정 추가 창의 기본 날짜도 그 사람 '오늘' (${r.formDate})`);
  }
}

await b.close();
done();
})();
