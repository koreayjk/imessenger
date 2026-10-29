// 🚗 차량 — km/원 단위 · 명의 · 보험사
const { launch, openApp, ok, done } = require('./_harness');

const setup = (unit, cur) => `(async () => {
  Object.assign(window.__DB, {
    communities: [{ id:'c1', name:'IMUSA', veh_unit:'${unit}', veh_currency:'${cur}' }],
    vehicles: [{ id:'v1', community_id:'c1', plate:'TKM3660', name:'스타리아', make:'Hyundai',
                 odometer:10000, odometer_at:'2026-01-02', owner_name:'IM USA', insurer:'Progressive',
                 sort:0, intervals:null }],
    vehicle_logs: [
      { id:'l1', community_id:'c1', vehicle_id:'v1', kind:'oil', title:'엔진오일',
        service_date:'2026-01-10', odometer:9000, cost:60, currency:'$' },
      { id:'l2', community_id:'c1', vehicle_id:'v1', kind:'tire', title:'타이어',
        service_date:'2026-02-10', odometer:9500, cost:90000, currency:'원' },
    ],
  });
  schoolSubMode = 'vehicle';
  await renderVehicleHub();
  await new Promise(r => setTimeout(r, 400));
  return { unit: VEH_UNIT, cur: VEH_CUR };
})()`;

const txt = `(() => document.getElementById('school-main').innerText)()`;

(async () => {
const b = await launch();

console.log('\n① 설정을 읽어 온다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(setup('km','원'));
  ok(r.unit === 'km' && r.cur === '원', '공동체 설정의 단위·통화를 읽는다');
  await pg.close(); }

console.log('\n② 거리는 보여줄 때만 바꾼다 (저장은 늘 마일)');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('mi','$'));
  const mi = await pg.evaluate(txt);
  await pg.evaluate(setup('km','원'));
  const km = await pg.evaluate(txt);
  ok(/10,000/.test(mi) && / mi/.test(mi), '마일이면 10,000 mi');
  ok(/16,093/.test(km) && /km/.test(km), 'km 면 16,093 km 로 바꿔 보여준다 (10,000 × 1.609344)');
  const kept = await pg.evaluate(`(() => (window.__DB.vehicles[0].odometer))()`);
  ok(kept === 10000, '표에 들어 있는 값은 그대로 마일이다 — 보기만 바뀐다');
  await pg.close(); }

console.log('\n③ 돈은 바꿔 계산하지 않는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('km','원'));
  const r = await pg.evaluate(`(async () => {
    vehOpen('v1'); await new Promise(r => setTimeout(r, 300));
    setVehTab('cost'); await new Promise(r => setTimeout(r, 300));
    return document.getElementById('school-main').innerText;
  })()`);
  ok(/\$60\.00/.test(r), '$ 로 적은 기록은 $ 로 남는다');
  ok(/90,000/.test(r), '원으로 적은 기록은 원으로 남는다');
  ok(/통화가 섞여 있어요/.test(r), '섞여 있으면 그렇다고 알려 준다 — 서로 다른 돈을 더하지 않는다');
  await pg.close(); }

console.log('\n④ 명의·보험사');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('mi','$'));
  const r = await pg.evaluate(`(async () => {
    vehEditCar('v1'); await new Promise(r => setTimeout(r, 300));
    return { owner: document.getElementById('vc-owner')?.value,
             insurer: document.getElementById('vc-insurer')?.value,
             odo: document.getElementById('vc-odo')?.value };
  })()`);
  ok(r.owner === 'IM USA', '명의 칸이 있고 값이 들어온다');
  ok(r.insurer === 'Progressive', '보험사 칸이 있고 값이 들어온다');
  ok(String(r.odo) === '10000', '마일일 때는 주행거리가 그대로');
  await pg.close(); }

console.log('\n⑤ km 로 적으면 마일로 되돌려 저장한다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('km','원'));
  const r = await pg.evaluate(`(async () => {
    vehEditCar('v1'); await new Promise(r => setTimeout(r, 300));
    const shown = document.getElementById('vc-odo').value;
    document.getElementById('vc-odo').value = '20000';      // 20,000 km 로 고친다
    document.getElementById('vc-owner').value = 'IM 아메리카';
    await saveVehCar();
    await new Promise(r => setTimeout(r, 400));
    const v = (window.__DB.vehicles || []).find(x => x.id === 'v1');
    return { shown, saved: v && v.odometer, owner: v && v.owner_name };
  })()`);
  ok(String(r.shown) === '16093', '폼에는 km 로 보인다');
  ok(r.saved === 12427, '20,000 km 를 12,427 마일로 되돌려 저장한다');
  ok(r.owner === 'IM 아메리카', '명의도 저장된다');
  await pg.close(); }

console.log('\n⑥ 새 정비 기록에는 지금 통화를 같이 적는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('km','원'));
  const r = await pg.evaluate(`(async () => {
    vehOpen('v1'); await new Promise(r => setTimeout(r, 300));
    vehNewLog('v1','oil'); await new Promise(r => setTimeout(r, 300));
    document.getElementById('vl-date').value = '2026-03-01';
    document.getElementById('vl-cost').value = '50000';
    document.getElementById('vl-odo').value = '32187';       // km
    await saveVehLog();
    await new Promise(r => setTimeout(r, 400));
    const rows = window.__DB.vehicle_logs || [];
    return rows[rows.length - 1];
  })()`);
  ok(r.currency === '원', '그때의 통화(원)가 같이 적힌다');
  ok(r.odometer === 20000, 'km 로 적은 주행거리도 마일로 되돌려 저장한다 (32,187 km → 20,000 mi)');
  await pg.close(); }

console.log('\n⑦ DB 설치 전에도 기록은 남는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(setup('mi','$'));
  const r = await pg.evaluate(`(async () => {
    vehOpen('v1'); await new Promise(r => setTimeout(r, 300));
    vehNewLog('v1','oil'); await new Promise(r => setTimeout(r, 300));
    document.getElementById('vl-date').value = '2026-04-01';
    document.getElementById('vl-cost').value = '70';
    let tries = 0, toast = '';
    const realToast = window.showUploadToast; window.showUploadToast = (x) => { toast = String(x||''); };
    const real = sb.from;
    sb.from = (t2) => { const q = real(t2);
      if (t2 === 'vehicle_logs') { const ins = q.insert.bind(q);
        q.insert = (v) => { tries++; if (v && 'currency' in v) {
            return { then: (res) => Promise.resolve({ data:null, error:{ message:"column vehicle_logs.currency does not exist" } }).then(res) }; }
          return ins(v); }; }
      return q; };
    await saveVehLog();
    sb.from = real; window.showUploadToast = realToast;
    await new Promise(r => setTimeout(r, 400));
    const rows = window.__DB.vehicle_logs || [];
    return { tries, last: rows[rows.length - 1], toast };
  })()`);
  ok(r.tries === 2, '통화 칸이 없으면 그것만 빼고 한 번 더 넣는다');
  ok(r.last && Number(r.last.cost) === 70, '기록 자체는 남는다 — 통화 때문에 기록을 잃지 않는다');
  ok(/차량_단위통화_DB설치\.sql/.test(r.toast), '무엇을 실행하면 되는지 알려 준다');
  await pg.close(); }

await b.close();
done();
})();
