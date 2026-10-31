// 🔑 비밀번호 찾기
const { launch, openApp, ok, done } = require('./_harness');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');

//  로그인 화면만 띄운다 (openApp 은 앱 안으로 들어가므로 따로 연다)
async function openAuth(b, hash) {
  const fs = require('fs');
  const pg = await b.newPage({ viewport: { width: 1280, height: 950 } });
  pg.on('pageerror', e => console.log('  ⚠️', e.message.slice(0, 130)));
  await pg.route('**', r => {
    const u = r.request().url();
    return (u.startsWith('file://') || u.startsWith('data:') || u.startsWith('blob:')) ? r.continue() : r.abort();
  });
  await pg.addInitScript(fs.readFileSync(path.join(__dirname, 'stub.js'), 'utf8'));
  await pg.addInitScript(`(() => {
    window.__sent = []; window.__updated = []; window.__signedOut = 0;
    window.__session = null; window.__resetErr = null; window.__updErr = null;
    window.supabase = { createClient: () => ({
      from: () => ({ select(){return this}, eq(){return this}, order(){return this}, limit(){return this},
                     single(){return this}, maybeSingle(){return this},
                     then(r){ return Promise.resolve({ data:null, error:null }).then(r); } }),
      rpc: () => ({ then:(r)=>Promise.resolve({data:null,error:null}).then(r) }),
      channel: () => ({ on(){return this}, subscribe(){return this} }), removeChannel(){},
      storage:{ from: () => ({ getPublicUrl: () => ({ data:{ publicUrl:'' } }) }) },
      functions:{ invoke: async () => ({ data:null, error:null }) },
      auth: {
        getSession: async () => ({ data:{ session: window.__session } }),
        onAuthStateChange(cb){ window.__authCb = cb; },
        signOut: async () => { window.__signedOut++; window.__session = null; return {}; },
        resetPasswordForEmail: async (email, opts) => { window.__sent.push({ email, opts });
          return { error: window.__resetErr }; },
        updateUser: async (patch) => { window.__updated.push(patch); return { error: window.__updErr }; },
        signInWithPassword: async () => ({ data:null, error:{ message:'no' } }),
      },
    }) };
  })()`);
  await pg.goto('file://' + path.join(ROOT, 'index.html') + (hash || ''));
  await pg.waitForTimeout(900);
  return pg;
}

(async () => {
const b = await launch();

console.log('\n① 로그인 화면에 길이 있다');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(() => {
    const f = document.getElementById('si-forgot');
    return { has: !!f, txt: f ? f.textContent : '',
             resetShown: getComputedStyle(document.getElementById('form-reset')).display };
  })()`);
  ok(r.has && /비밀번호를 잊/.test(r.txt), "'비밀번호를 잊으셨나요?' 가 보인다");
  ok(r.resetShown === 'none', '평소에는 찾기 칸이 닫혀 있다');
  await pg.close(); }

console.log('\n② 눌러서 열고, 적어 둔 이메일을 가져온다');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(() => {
    document.getElementById('si-email').value = ' mom@example.com ';
    showResetForm();
    return { shown: getComputedStyle(document.getElementById('form-reset')).display,
             signin: getComputedStyle(document.getElementById('form-signin')).display,
             email: document.getElementById('rs-email').value };
  })()`);
  ok(r.shown === 'flex' && r.signin === 'none', '찾기 칸이 열리고 로그인 칸이 닫힌다');
  ok(r.email === 'mom@example.com', '로그인 칸에 적던 이메일을 그대로 가져온다 (앞뒤 공백은 떼고)');
  await pg.close(); }

console.log('\n③ 메일을 보낸다');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(async () => {
    showResetForm();
    document.getElementById('rs-email').value = 'mom@example.com';
    await sendResetEmail();
    await new Promise(r => setTimeout(r, 200));
    return { sent: window.__sent, msg: document.getElementById('rs-msg').textContent };
  })()`);
  ok(r.sent.length === 1 && r.sent[0].email === 'mom@example.com', '그 주소로 보낸다');
  ok(/index\.html$/.test(r.sent[0].opts.redirectTo), '돌아올 주소를 같이 보낸다');
  ok(!/#/.test(r.sent[0].opts.redirectTo), '공유 링크 같은 꼬리표는 떼고 보낸다');
  ok(/스팸함/.test(r.msg) && /한 시간/.test(r.msg), '메일이 안 보일 때와 유효 시간을 알려 준다');
  await pg.close(); }

console.log('\n④ 주소가 엉터리면 보내지 않는다');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(async () => {
    showResetForm();
    document.getElementById('rs-email').value = '그냥글자';
    await sendResetEmail();
    await new Promise(r => setTimeout(r, 150));
    return { sent: window.__sent.length, msg: document.getElementById('rs-msg').textContent };
  })()`);
  ok(r.sent === 0, '보내지 않는다');
  ok(/정확히/.test(r.msg), '왜 안 되는지 말해 준다');
  await pg.close(); }

console.log('\n⑤ 없는 계정이어도 똑같이 답한다 (가입 여부를 흘리지 않는다)');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(async () => {
    showResetForm();
    window.__resetErr = { message: 'User not found' };
    document.getElementById('rs-email').value = 'nobody@example.com';
    await sendResetEmail();
    await new Promise(r => setTimeout(r, 150));
    return document.getElementById('rs-msg').textContent;
  })()`);
  ok(/보냈어요/.test(r), '보냈다고 똑같이 답한다');
  ok(!/없|not found|존재/i.test(r), "'그런 계정 없다' 고 흘리지 않는다 — 남의 가입 여부를 알아내는 길이 된다");
  await pg.close(); }

console.log('\n⑥ 메일 링크로 들어오면 — 앱으로 바로 들어가지 않는다');
{ const pg = await openAuth(b, '#access_token=abc&type=recovery');
  const r = await pg.evaluate(`(async () => {
    window.__session = { user: { id:'p1' } };
    await new Promise(r => setTimeout(r, 600));
    return { newpw: getComputedStyle(document.getElementById('form-newpw')).display,
             app: getComputedStyle(document.getElementById('app')).display,
             auth: getComputedStyle(document.getElementById('auth-screen')).display,
             recovery: IS_RECOVERY };
  })()`);
  ok(r.recovery === true, '재설정 링크로 들어온 것을 알아챈다');
  ok(r.newpw === 'flex', "'새 비밀번호 정하기' 가 뜬다");
  ok(r.app === 'none' && r.auth === 'flex', '세션이 있어도 앱으로 들여보내지 않는다 — 이 방문의 목적은 비밀번호를 정하는 것이다');
  await pg.close(); }

console.log('\n⑦ 보통 주소로 들어오면 그대로');
{ const pg = await openAuth(b);
  const r = await pg.evaluate(`(() => ({ recovery: IS_RECOVERY,
    newpw: getComputedStyle(document.getElementById('form-newpw')).display }))()`);
  ok(r.recovery === false, '재설정 링크가 아니면 그대로 둔다');
  ok(r.newpw === 'none', "'새 비밀번호' 칸이 뜨지 않는다");
  await pg.close(); }

console.log('\n⑧ 새 비밀번호 정하기');
{ const pg = await openAuth(b, '#access_token=abc&type=recovery');
  await pg.waitForTimeout(500);
  const short = await pg.evaluate(`(async () => {
    document.getElementById('np-pw1').value = '123';
    document.getElementById('np-pw2').value = '123';
    await saveNewPassword(); await new Promise(r=>setTimeout(r,120));
    return { n: window.__updated.length, msg: document.getElementById('np-msg').textContent };
  })()`);
  ok(short.n === 0 && /6자/.test(short.msg), '6자보다 짧으면 안 바꾼다');

  const diff = await pg.evaluate(`(async () => {
    document.getElementById('np-pw1').value = 'abcdef1';
    document.getElementById('np-pw2').value = 'abcdef2';
    await saveNewPassword(); await new Promise(r=>setTimeout(r,120));
    return { n: window.__updated.length, msg: document.getElementById('np-msg').textContent };
  })()`);
  ok(diff.n === 0 && /서로 달라요/.test(diff.msg), '두 번 적은 것이 다르면 안 바꾼다');

  const okr = await pg.evaluate(`(async () => {
    document.getElementById('np-pw1').value = 'newpass1';
    document.getElementById('np-pw2').value = 'newpass1';
    await saveNewPassword(); await new Promise(r=>setTimeout(r,250));
    return { updated: window.__updated, out: window.__signedOut,
             signin: getComputedStyle(document.getElementById('form-signin')).display,
             msg: document.getElementById('si-msg').textContent };
  })()`);
  ok(okr.updated.length === 1 && okr.updated[0].password === 'newpass1', '맞게 적으면 바꾼다');
  ok(okr.out === 1, '바꾼 뒤 로그아웃한다 — 새 비밀번호가 맞는지 본인이 바로 확인하게');
  ok(okr.signin === 'flex' && /새 비밀번호로 로그인/.test(okr.msg), '로그인 칸으로 돌아가 무엇을 하면 되는지 말해 준다');
  await pg.close(); }

console.log('\n⑨ 링크가 만료됐으면 그렇다고 말한다');
{ const pg = await openAuth(b, '#access_token=abc&type=recovery');
  await pg.waitForTimeout(500);
  const r = await pg.evaluate(`(async () => {
    window.__updErr = { message: 'Auth session missing or expired' };
    document.getElementById('np-pw1').value = 'newpass1';
    document.getElementById('np-pw2').value = 'newpass1';
    await saveNewPassword(); await new Promise(r=>setTimeout(r,150));
    return document.getElementById('np-msg').textContent;
  })()`);
  ok(/만료/.test(r) && /다시 보내/.test(r), '만료됐다고 말하고 다시 받는 길을 알려 준다');
  await pg.close(); }

await b.close();
done();
})();
