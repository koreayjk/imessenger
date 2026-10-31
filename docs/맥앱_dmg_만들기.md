# 🖥 맥 앱 (.dmg) 만들기

선생님들께 **파일로 나눠드리는** 맥 앱입니다. 받으신 분은 `.dmg` 를 열고
TCS 를 **응용 프로그램** 폴더로 끌어다 놓으면 끝입니다.

---

## 중요한 것 하나 — 화면은 안 들어 있습니다

이 앱은 화면을 제 안에 담지 않고 **살아 있는 주소를 띄웁니다.**

> https://koreayjk.github.io/imessenger/

그래서 **제가 고친 것이 맥 앱에도 바로 반영됩니다.** 고칠 때마다 `.dmg`
를 다시 만들어 나눠드릴 필요가 없습니다. 한 번 나눠드리면 끝입니다.

### 🔴 다만 이번(1.1.0)은 꼭 다시 만들어 나눠드려야 합니다

화면이 아니라 **앱 자체의 자격**이 바뀌었기 때문입니다. 화면만 받아오는
것으로는 안 됩니다.

지금까지 맥 앱에는 **마이크를 쓸 자격이 아예 없었습니다.** 그런데 맥은
자격이 없다고 거절하지 않고, 묻지도 않은 채 **조용한 마이크**를 내줍니다.
그래서 전화는 멀쩡히 걸리고 받아지는데, **그 사람 목소리만 상대에게 가지
않았습니다.** 오류가 하나도 안 나서 찾는 데 오래 걸렸습니다.

| 넣은 것 | 없으면 |
|---|---|
| `NSMicrophoneUsageDescription` | 맥이 **묻지를 않습니다** → 조용한 마이크 |
| `com.apple.security.device.audio-input` | hardened runtime 이 막습니다 |
| 권한 손잡이(`setPermissionRequestHandler`) | 맥에게 물어보지도 않고 지나갑니다 |

1.1.0 을 깔면 **첫 전화 때 맥이 스스로 물어봅니다.** 「TCS 정보」에서
판 번호가 **1.1.0** 인지 보시면 새것인지 알 수 있습니다.

### 이미 1.0.0 을 깐 분들에게는 — 화면이 알려 줍니다

맥 앱은 **스스로 업데이트하지 않습니다.** 그래서 이미 쓰시는 분들은 새 판이
나온 줄을 알 길이 없습니다. 그런데 맥 앱은 화면을 늘 여기서 받아갑니다 —
그러니 **화면이 알려 줍니다.** 껍데기를 안 고쳐도 통합니다.

옛 판으로 앱을 열면 맨 위에 이 띠가 뜹니다:

> 🖥 맥 앱이 옛 판이에요 (1.0.0). 새 판 1.1.0 을 받아 다시 깔아주세요 —
> 전화할 때 제 목소리가 상대에게 가지 않던 것을 고쳤습니다. 　［오늘은 그만］

「오늘은 그만」을 눌러도 **하루 뒤 다시 뜹니다.** 영영 숨기면 전화가 안 되는
채로 지내게 되기 때문입니다. 그리고 옛 판으로 전화를 걸면 통화 화면에도
**"설정을 고쳐도 이 판으로는 안 됩니다"** 라고 적힙니다 — 설정만 들여다보다
끝나지 않게요.

그러니 **파일만 전해 주시면 됩니다.** 따로 공지하지 않으셔도 앱이 말합니다.

> 새 판을 내실 때는 `index.html` 의 `DESKTOP_VER` 과 `desktop/package.json`
> 의 `version` 을 같이 올리세요. 이 둘이 띠를 띄울지 말지를 정합니다.

### 맥이 안 묻고 조용하면

맥은 **앱 하나당 답을 한 번만 기억합니다.** 예전 앱이 이미 물어본
적이 있으면(자격 없이 물었어도) 그 답이 남아 있어서 **다시 안 묻습니다.**

그럴 때는 앱이 스스로 알아채고 이렇게 띄웁니다:

> ⚠️ **맥이 TCS의 마이크 사용을 막고 있어요**
> 시스템 설정 → 개인정보 보호 및 보안 → 마이크 에서 TCS 를 켜 주세요.
> 　［**설정 열기**］　［나중에］

「설정 열기」로 바로 갑니다. 그런데 **목록에 TCS 가 아예 안 보이면**
맥의 기억을 지워야 합니다:

```bash
tccutil reset Microphone io.github.koreayjk.tcs.desktop
```

치고 앱을 다시 열면 **처음처럼 물어봅니다.**

---

## 🖥 만들기 (맥북에서)

```bash
cd ~/imessenger/desktop
npm install
npm run dmg
```

처음 한 번은 일렉트론을 내려받느라 몇 분 걸립니다.
다 되면 `desktop/dist/TCS-1.1.0-arm64.dmg` 가 생깁니다 — **M칩 맥용**입니다.

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

#### ⚠️ 먼저: 어느 애플 ID 인지 확인하세요

여기서 한 번 크게 헤맸습니다. **개발자 계정과 평소 쓰는 애플 ID 가
다를 수 있습니다.** 앱 암호는 **만든 그 계정으로만** 통해서, 계정이
다르면 암호를 몇 번을 새로 만들어도 이 오류만 반복됩니다:

```
HTTP status code: 401. Invalid credentials.
```

**developer.apple.com → Account** 오른쪽 위에 뜨는 이메일이
`APPLE_ID` 에 들어갈 그 이메일입니다. 그 **같은 계정**으로
appleid.apple.com 에 들어가 앱 암호를 만드세요.

#### 앱 암호 만들고 저장하기

appleid.apple.com → 로그인 및 보안 → **앱 암호** → 이름 `tcs-notary`

받은 값은 키체인에 넣습니다. 저장하기 전에 애플에 물어보기 때문에,
**맞는지 그 자리에서 알 수 있습니다** (빌드를 돌려볼 필요가 없습니다):

```bash
xcrun notarytool store-credentials "tcs-notary" \
  --apple-id "developer.apple.com 에 뜬 그 이메일" \
  --team-id "H6B99PYZ8W"
```

`Credentials saved to Keychain` 이 뜨면 맞은 것입니다.

#### 만들기

```bash
cd ~/imessenger/desktop
export APPLE_KEYCHAIN_PROFILE="tcs-notary"
export APPLE_TEAM_ID="H6B99PYZ8W"
npm run dmg
```

electron-builder 가 **알아서 공증까지** 합니다. `package.json` 에
더 적을 것은 없습니다.

키체인을 쓰지 않고 그때그때 넣으셔도 됩니다:

```bash
export APPLE_ID="developer.apple.com 에 뜬 그 이메일"
export APPLE_APP_SPECIFIC_PASSWORD='abcd-efgh-ijkl-mnop'
export APPLE_TEAM_ID="H6B99PYZ8W"
```

붙임표(`-`)까지 그대로 넣어야 합니다 (19자). 작은따옴표를 쓰면
zsh 가 중간 글자를 건드리지 않습니다.

애플 서버에 보내고 답을 기다리므로 **몇 분 더 걸립니다.**
끝나면 로그에 `notarization successful` 이 뜹니다.

🔐 **앱 암호는 git 에 올리지 마세요.** 위 `export` 는 그 터미널 창에서만 삽니다.

### 제대로 됐는지 보기

```bash
codesign -dv --verbose=2 dist/mac-arm64/TCS.app 2>&1 | grep -E "Authority|TeamIdentifier"
spctl -a -vvv -t install dist/mac-arm64/TCS.app
xcrun stapler validate dist/TCS-1.1.0-arm64.dmg
```

`spctl` 이 **`accepted`** 와 **`source=Notarized Developer ID`** 라고 하면
받으시는 분이 그냥 열 수 있습니다.

### 401 이 나면 — 빌드 말고 5초짜리로 확인

10분짜리 빌드를 다시 돌리지 마세요. 자격만 따로 물어볼 수 있습니다:

```bash
xcrun notarytool history \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

값이 어떻게 들어갔는지는 암호를 드러내지 않고 볼 수 있습니다:

```bash
echo "ID   = [$APPLE_ID]"
echo "길이  = ${#APPLE_APP_SPECIFIC_PASSWORD}"
echo "모양  = $(echo "$APPLE_APP_SPECIFIC_PASSWORD" | sed 's/[a-zA-Z]/x/g; s/[0-9]/9/g')"
```

`길이 = 19` · `모양 = xxxx-xxxx-xxxx-xxxx` 가 나와야 합니다.

| 보이는 것 | 뜻 |
|---|---|
| 길이 16 | 붙임표를 뺐습니다 |
| 길이 20 이상 | 앞뒤에 따옴표·공백이 딸려왔습니다 |
| `ID = []` | 그 터미널 창에 `export` 가 안 살아 있습니다 (창을 새로 열면 사라집니다) |
| 모양은 맞는데 401 | **애플 ID 가 다릅니다** — 맨 위 ⚠️ 를 보세요 |

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

- 우리 주소에서 온 **마이크·카메라·알림**만 열어 줍니다. 그 밖의 권한은
  우리 주소라도 막습니다 (일렉트론은 손잡이를 안 달면 거의 다 열어 줍니다)

이 규칙들은 시험으로 확인합니다 — `node test/맥앱권한.js` (21가지).
가짜 일렉트론 위에서 **진짜 `main.js` 를 돌려** 권한 손잡이에게 직접
물어봅니다.

---

## 이것 말고 더 쉬운 길도 있습니다

맥에서는 **Safari → 공유 → 독에 추가** 가 더 간단합니다. 서명도
공증도 `.dmg` 도 없이, 독에 아이콘이 생기고 알림도 받습니다.
파일로 나눠드려야 할 이유가 없으면 그쪽이 낫습니다.
