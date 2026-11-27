//  📖 성경 본문은 앱에 담지 않는다 — 구절 주소만
//
//  2026-11-27 선교사님 지시:
//    「성경 번역본은 그냥 영어와 한글 성경을 빼주고 제목만 넣어줘
//      창세기 1:1 이렇게」
//
//  까닭은 저작권입니다. 앱에 실려 있던 것은 —
//    · 성구암송 : 개역개정(대한성서공회) 60구절 + NIV(Biblica) 60구절
//                 표에도 있었고 db/성구암송_내용_60구절.sql 에도 그대로
//                 적혀 공개 저장소에 올라가 있었습니다.
//    · 오늘의 묵상 : 구절을 치면 bible-api.com 에서 ESV(Crossway) 본문을
//                 받아 와 daily_word.scripture_text 에 저장했습니다.
//  공개 API 로 받아올 수 있다고 해서 앱에 실어도 되는 것은 아닙니다.
//
//  이제 「갈라디아서 2:20」 처럼 **주소만** 두고, 본문은 각자 성경책이나
//  성경 앱에서 찾아 읽습니다. 요리문답(웨스트민스터 소교리문답)은
//  퍼블릭 도메인이라 그대로 둡니다.
//
//  재는 것:
//   ① 본문이 없어도 성구암송 줄이 주소를 제대로 보여주고 안 깨진다
//   ② 본문이 있으면(공동체가 직접 넣은 것) 그건 그대로 보여준다
//   ③ 요리문답은 그대로다
//   ④ 묵상 폼에 본문 칸이 없고, 왜 없는지 적혀 있다
//   ⑤ 묵상을 저장할 때 본문을 null 로 보낸다 (옛 줄도 지워진다)
//   ⑥ 코드 어디에도 bible-api 를 부르는 곳이 없다
const { launch, openApp, ok, done } = require('./_harness');
const fs = require('fs');

(async () => {
const b = await launch();

// ── ⑥ 소스에 흔적이 없나 (먼저, 파일만 봐도 되는 것) ──────────
console.log('\n⑥ 코드에 남은 흔적');
{
  const src = fs.readFileSync(__dirname + '/../index.html', 'utf8');
  //  주석에 까닭을 적어 두었으므로, '부르는 코드' 가 있는지를 본다
  ok(!/fetch\(`https:\/\/bible-api\.com/.test(src), 'bible-api.com 을 부르지 않는다');
  ok(!/function fetchScripture/.test(src),        'fetchScripture() 가 없다');
  ok(!/scheduleScriptureFetch\(\)/.test(src),     'scheduleScriptureFetch() 를 부르는 곳이 없다');
  ok(!/id="dw-text"/.test(src),                   '묵상 본문 입력칸이 없다');
  ok(/scripture_text: null/.test(src),            '저장할 때 본문을 null 로 보낸다');
  ok(!/escHtml\(row\.scripture_text\)/.test(src), '화면에 본문을 그리지 않는다');

  //  저장소 SQL 에도 본문이 없어야 한다 (공개 저장소입니다)
  const sql = fs.readFileSync(__dirname + '/../db/성구암송_내용_60구절.sql', 'utf8');
  const vals = sql.match(/^\s*\('verse',.*$/gm) || [];
  ok(vals.length === 120, 'SQL 에 120줄이 그대로 있다', vals.length);
  const longest = Math.max(...vals.map(v => v.length));
  ok(longest < 130, '어느 줄도 본문이 들어갈 만큼 길지 않다', '가장 긴 줄 ' + longest + '자');
  ok(/body/.test(sql) === true && !/insert into public\.memory_items \([^)]*body/.test(sql),
     'insert 에 body 칸이 없다 (확인 질의에만 body 가 나온다)');
  ok(/대한성서공회|Biblica/.test(sql), '왜 뺐는지 파일에 적어 두었다');
}

// ── ①②③ 화면 ───────────────────────────────────────────────
console.log('\n① 본문 없는 성구암송 줄');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(() => {
    ME.id = 'me'; ME.name = '학생';
    memChecks = {}; memHide = false; memMode = 'self';
    const noBody  = memRowHtml({ id:'v1', kind:'verse', no:2, title:'갈라디아서 2:20',
                                 body:null, answer:null }, null);
    const hasBody = memRowHtml({ id:'v2', kind:'verse', no:3, title:'로마서 12:1',
                                 body:'우리 공동체가 직접 넣은 본문', answer:null }, null);
    const cate    = memRowHtml({ id:'c1', kind:'catechism', no:1, title:'제1문',
                                 body:'사람의 제일 되는 목적이 무엇인가?',
                                 answer:'사람의 제일 되는 목적은 하나님을 영화롭게 하는 것이다.' }, null);
    const strip = (h) => { const d = document.createElement('div'); d.innerHTML = h; return d.innerText; };
    return {
      noBodyText: strip(noBody), noBodyHtml: noBody,
      hasBodyText: strip(hasBody),
      cateText: strip(cate),
    };
  });
  ok(/갈라디아서 2:20/.test(r.noBodyText), '구절 주소가 보인다', r.noBodyText.replace(/\s+/g,' ').slice(0,40));
  ok(/외웠어요/.test(r.noBodyText),        '「외웠어요」 단추는 그대로 있다');
  ok(!/undefined|null/.test(r.noBodyHtml), '본문이 없어도 undefined·null 이 안 새어 나온다');

  console.log('\n② 공동체가 직접 넣은 본문은 그대로');
  ok(/우리 공동체가 직접 넣은 본문/.test(r.hasBodyText),
     '본문이 있으면 보여준다 (권리를 받은 공동체는 직접 넣을 수 있다)');

  console.log('\n③ 요리문답은 그대로');
  ok(/사람의 제일 되는 목적이 무엇인가/.test(r.cateText), '문제가 보인다');
  ok(/하나님을 영화롭게/.test(r.cateText),                '답도 보인다 (퍼블릭 도메인)');
  await pg.close();
}

// ── ④⑤ 묵상 ────────────────────────────────────────────────
console.log('\n④ 묵상 폼');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    const modal = document.getElementById('daily-word-modal');
    return {
      hasText: !!document.getElementById('dw-text'),
      hasVerse: !!document.getElementById('dw-verse'),
      hasTitle: !!document.getElementById('dw-title'),
      says: modal ? /본문은 담지 않습니다/.test(modal.innerText) : false,
      ph: (document.getElementById('dw-verse') || {}).placeholder || '',
    };
  });
  ok(!r.hasText, '본문 입력칸이 없다');
  ok(r.hasVerse && r.hasTitle, '구절 주소 칸과 제목 칸은 그대로 있다');
  ok(r.says, '왜 본문이 없는지 화면에 적혀 있다');
  ok(/베드로전서/.test(r.ph), '예시도 한글 구절 주소로 바뀌었다', r.ph);

  console.log('\n⑤ 묵상 저장');
  const w = await pg.evaluate(async () => {
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    showDailyWordForm('2026-11-27');
    document.getElementById('dw-url').value = 'https://tabletalkmagazine.com/daily-study/x';
    document.getElementById('dw-verse').value = '창세기 1:1';
    document.getElementById('dw-title').value = '태초에';
    await submitDailyWord();
    await new Promise(r => setTimeout(r, 400));
    const up = (window.__ins || []).concat(window.__upd || []).filter(x => x.t === 'daily_word');
    const row = up.length ? (up[0].rows ? up[0].rows[0] : up[0].vals) : null;
    return { row };
  });
  ok(w.row && 'scripture_text' in w.row, '본문 칸을 보내긴 한다 (옛 줄을 지우려고)');
  ok(w.row && w.row.scripture_text === null, '그 값이 null 이다', String(w.row && w.row.scripture_text));
  ok(w.row && w.row.verse === '창세기 1:1', '구절 주소는 그대로 저장된다', w.row && w.row.verse);
  ok(w.row && w.row.title === '태초에', '제목도 저장된다', w.row && w.row.title);
  await pg.close();
}

await b.close();
done();
})();
