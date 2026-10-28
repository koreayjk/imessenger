# 🧪 시험 묶음

```bash
bash test/run.sh              # 전부
bash test/run.sh 학부모권한    # 한 묶음만
```

진짜 `index.html` 을 크로미움으로 열어서 **화면을 재어** 확인합니다. 코드를 읽어
그럴듯하면 통과시키는 시험은 고친 뒤에도 똑같이 통과해서, 무엇도 지켜주지 못합니다.

## 규칙 두 가지

**1. 바깥으로 나가지 않습니다.** `_harness.js` 가 `file://` 말고 모든 요청을 끊습니다.
`index.html` 19줄이 CDN 에서 supabase-js 를 받아오는데, 그게 받아지면 `window.supabase`
가 진짜 라이브러리로 덮어써져서 **시험이 운영 데이터베이스에 말을 겁니다.**
실제로 한 번 그랬습니다(읽기였지만, 쓰는 시험이었다면 운영에 글이 들어갔을 겁니다).

**2. 되돌려 보고 ❌ 가 나오는지 확인합니다.** 고친 곳을 되돌렸을 때 빨간 줄이 안 뜨면
그 확인은 아무것도 지키지 못하는 것이므로, 확인을 다시 씁니다.

## 파일

| | |
|---|---|
| `_harness.js` | 브라우저 띄우기 · 가짜 Supabase · `ok()` / `done()` |
| `stub.js` | 가짜 공동체 자료 (`window.__seed()`) |
| `run.sh` | 묶음 전부 돌리기 |
| `학부모권한.js` | 1:1 제한 · 방 운영 권한 · 역할 칸 · 내 아이 용돈 |

## 새 묶음 쓰는 법

```js
const { launch, openApp, ok, done } = require('./_harness');
(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'parent' });   // 'teacher' | 'parent' | 'student'
  const r = await pg.evaluate(() => /* 화면을 재서 돌려준다 */);
  ok(r === '바라던 것', '사람이 읽을 수 있는 문장으로');
  await pg.close(); await b.close(); done();
})();
```

`openApp` 뒤에는 `window.__DB`(가짜 표), `window.__ins`(넣은 것), `window.__upd`(고친 것)
를 들여다볼 수 있습니다. 오류를 흉내 내려면 `window.__err = { table:'...', e:{...} }`.

> ⚠️ 예전에는 이 도구들이 `/tmp` 에만 있었습니다. 컨테이너가 회수되면서 묶음 56개를
> 통째로 잃었습니다. 반드시 저장소 안에 두세요.
