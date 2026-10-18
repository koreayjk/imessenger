# 🖥 맥 앱 (.dmg) 만들기

선생님들께 **파일로 나눠드리는** 맥 앱입니다. 받으신 분은 `.dmg` 를 열고
TCS 를 **응용 프로그램** 폴더로 끌어다 놓으면 끝입니다.

---

## 중요한 것 하나 — 화면은 안 들어 있습니다

이 앱은 화면을 제 안에 담지 않고 **살아 있는 주소를 띄웁니다.**

> https://koreayjk.github.io/imessenger/

그래서 **제가 고친 것이 맥 앱에도 바로 반영됩니다.** 고칠 때마다 `.dmg`
를 다시 만들어 나눠드릴 필요가 없습니다. 한 번 나눠드리면 끝입니다.

---

## 🖥 만들기 (맥북에서)

```bash
cd ~/imessenger/desktop
npm install
npm run dmg
```

처음 한 번은 일렉트론을 내려받느라 몇 분 걸립니다.
다 되면 `desktop/dist/TCS-1.0.0-arm64.dmg` 가 생깁니다 — **M칩 맥용**입니다.

> 먼저 켜 보고 싶으시면 `npm start` — 묶지 않고 바로 띄웁니다.

### 인텔 맥을 쓰시는 분이 있으면

기본은 **M칩 하나만** 만듭니다. 둘 다 만들면 시간도 디스크도 두 배라서요
(8GB 맥북에서는 이게 꽤 차이 납니다). 인텔 맥이 필요하면:

```bash
npm run dmg:intel    # 인텔용만
npm run dmg:all      # 둘 다
```

받으시는 분이 어떤 맥인지 모르면 `dmg:all` 로 두 개를 만들어
"M칩이면 arm64, 아니면 다른 것" 이라고 알려주시면 됩니다.
(2020년 이후 맥은 거의 다 M칩입니다)

---

## 서명은 이미 됩니다 — 공증만 남았습니다

키체인에 **Developer ID Application** 인증서가 이미 있어서,
`npm run dmg` 만 해도 **서명까지 자동으로 끝납니다.** 로그에 이렇게 찍힙니다:

```
signing ... identityName=Developer ID Application: IM AMERICA GROUP CORP (H6B99PYZ8W)
```

남은 건 **공증(notarization)** 하나입니다. 서명만 하고 공증을 안 하면,
받으신 분이 처음 열 때 이렇게 됩니다:

1. **"Apple이 악성 소프트웨어 여부를 확인할 수 없습니다"** 라며 막힙니다
2. **시스템 설정 → 개인정보 보호 및 보안** 으로 들어가
3. 아래쪽 **"확인 없이 열기"** 를 눌러야 합니다

(macOS 15부터 Control-클릭으로 넘기는 길이 막혔습니다)

### 공증하기 — 설정은 안 건드립니다

**앱 암호**만 하나 만들면 됩니다:
appleid.apple.com → 로그인 및 보안 → **앱 암호** → 이름 `tcs-notary`

그 값을 넣고 만들면 끝입니다:

```bash
cd ~/imessenger/desktop
export APPLE_ID="imamerica2414@gmail.com"
export APPLE_APP_SPECIFIC_PASSWORD="위에서-받은-앱-암호"
export APPLE_TEAM_ID="H6B99PYZ8W"
npm run dmg
```

이 셋이 있으면 electron-builder 가 **알아서 공증까지** 합니다.
`package.json` 에 더 적을 것은 없습니다. (셋 중 하나라도 빠지면
"env var needs to be set" 이라며 알려줍니다)

애플 서버에 보내고 답을 기다리므로 **몇 분 더 걸립니다.**
끝나면 로그에 `notarization successful` 이 뜹니다.

🔐 **앱 암호는 git 에 올리지 마세요.** 위 `export` 는 그 터미널 창에서만 삽니다.

### 제대로 됐는지 보기

```bash
codesign -dv --verbose=2 dist/mac-arm64/TCS.app 2>&1 | grep -E "Authority|TeamIdentifier"
spctl -a -vvv -t install dist/mac-arm64/TCS.app
xcrun stapler validate dist/TCS-1.0.0-arm64.dmg
```

`spctl` 이 **`accepted`** 와 **`source=Notarized Developer ID`** 라고 하면
받으시는 분이 그냥 열 수 있습니다.

---

## 알아두실 것

| | |
|---|---|
| **창을 열어두면 알림이 옵니다** | 앱이 떠 있는 동안 새 메시지 알림이 뜹니다 |
| **앱을 닫으면 알림이 안 옵니다** | 맥 앱에는 백그라운드 푸시가 없습니다. 그건 아이폰 앱과 웹(사파리 독에 추가)이 합니다 |
| **인터넷이 필요합니다** | 화면을 받아오므로, 끊기면 "인터넷에 닿지 않아요" 가 뜹니다 |
| **창 크기를 기억합니다** | 다음에 열면 그 자리 그 크기로 |

## 안전하게 해둔 것

남의 서버에서 받아온 화면을 띄우는 앱이라, 그 화면에 **컴퓨터를 건드릴
힘을 주지 않았습니다.** 아이들이 쓰는 앱이라 느슨하게 두지 않았습니다.

- `nodeIntegration` 꺼짐 · `contextIsolation` 켜짐 · `sandbox` 켜짐
- **우리 주소 밖으로는 앱 안에서 가지 않습니다.** 바깥 링크는 진짜
  브라우저로 넘깁니다
- `file:` · `javascript:` 주소는 **아무 데도 열지 않습니다**

이 규칙들은 시험 28가지로 확인했습니다 (`/tmp/claude-0/mem/dmg.js`).

---

## 이것 말고 더 쉬운 길도 있습니다

맥에서는 **Safari → 공유 → 독에 추가** 가 더 간단합니다. 서명도
공증도 `.dmg` 도 없이, 독에 아이콘이 생기고 알림도 받습니다.
파일로 나눠드려야 할 이유가 없으면 그쪽이 낫습니다.
