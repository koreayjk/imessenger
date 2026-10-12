# TCS 안드로이드 앱 (Play 스토어) — 준비물과 순서

TCS 웹앱을 그대로 감싸서(TWA) 안드로이드 앱으로 올립니다.
**도메인은 필요 없습니다.** `koreayjk.github.io` 로 됩니다.

---

## 0. 먼저 — 딱 하나 정하실 것

**패키지 이름(packageId)** 은 한 번 올리면 **영영 못 바꿉니다.**
회사 도메인이 있으시면 그걸 쓰시는 게 좋습니다.

| 지금 적어 둔 값 | `io.github.koreayjk.tcs` |
|---|---|
| 회사 도메인이 `example.com` 이라면 | `com.example.tcs` |

바꾸시려면 `twa/twa-manifest.json` 과 `twa/assetlinks.json` **두 곳 모두** 고쳐야 합니다.

---

## 1. `koreayjk.github.io` 저장소 만들기 (5분, 무료)

안드로이드는 "이 앱이 이 사이트의 주인이 맞나"를 **주소 맨 앞**에서만 확인합니다.
TCS 는 `/imessenger/` 안에 있지만, 확인 파일은 맨 앞에 놓여야 합니다.

```
https://koreayjk.github.io/.well-known/assetlinks.json   ← 여기
```

지금 그 자리는 비어 있습니다(404). 저장소를 하나 더 만들면 채워집니다.

1. GitHub 에서 **새 저장소**를 만듭니다. 이름은 **정확히** `koreayjk.github.io`
2. 공개(Public)로 만듭니다
3. 그 안에 파일 두 개를 넣습니다

```
koreayjk.github.io/
├── .nojekyll                     ← 빈 파일. 없으면 .well-known 폴더가 숨겨져 404 가 납니다
└── .well-known/
    └── assetlinks.json           ← 이 폴더의 assetlinks.json 을 올리세요
```

4. Settings → Pages → Source 를 `main` 브랜치로 두면 몇 분 뒤 열립니다

> ⚠️ `.nojekyll` 을 빠뜨리면 GitHub 이 점으로 시작하는 폴더를 숨깁니다.
> 가장 흔히 걸리는 함정입니다.

---

## 2. 앱 만들기 — 두 가지 길

### 길 ① PWABuilder (쉬움 · 추천)

1. <https://www.pwabuilder.com> 에 `https://koreayjk.github.io/imessenger/` 를 넣습니다
2. **Package for stores → Android** 를 고릅니다
3. **Package ID** 를 위에서 정한 값으로 바꿉니다
4. 내려받으면 `.aab` 파일과 `assetlinks.json`, 그리고 **서명 키**가 함께 들어 있습니다

> 🔐 **서명 키(`.keystore`)와 그 비밀번호를 반드시 안전한 곳에 보관하세요.**
> 잃어버리면 앱 업데이트가 영영 막힙니다. **git 에 절대 커밋하지 마세요.**

### 길 ② Bubblewrap (손이 더 가지만 내 손 안에서)

```bash
npm i -g @bubblewrap/cli
mkdir tcs-android && cd tcs-android
cp /path/to/imessenger/twa/twa-manifest.json .
bubblewrap init --manifest https://koreayjk.github.io/imessenger/manifest.webmanifest
bubblewrap build
```

처음 한 번은 JDK 와 안드로이드 SDK 를 자동으로 내려받습니다(용량이 큽니다).
`twa-manifest.json` 을 이미 채워 두었으니 물어보는 값은 그대로 엔터만 치시면 됩니다.

---

## 3. 순서를 꼭 지켜주세요 ⚠️

`assetlinks.json` 에 넣는 지문은 **내 키스토어 것이 아닙니다.**
플레이가 다시 서명한 **앱 서명 키**의 지문입니다. 그래서 순서가 이렇습니다.

```
① 앱(.aab) 빌드
② Play Console 에 업로드 (내부 테스트로 올리면 충분)
③ Play Console → 설정 → 앱 서명 → 'SHA-256 인증서 지문' 복사
④ 그 지문을 assetlinks.json 에 넣고 koreayjk.github.io 에 올리기
⑤ 앱을 열어 확인 — 주소창이 안 보이면 성공
```

먼저 올려 두면 지문이 안 맞아서 **주소창이 뜨는 앱**이 됩니다
(동작은 하지만 앱처럼 보이지 않습니다).

확인하실 때:
<https://developers.google.com/digital-asset-links/tools/generator>

---

## 4. Play Console 에서 챙길 것

이미 두 개를 올려 보셨으니 익숙하시겠지만, TCS 에서 특히 걸리는 것만 적습니다.

| 항목 | 값 |
|---|---|
| 개인정보처리방침 | `https://koreayjk.github.io/imessenger/terms.html` ✅ 이미 살아 있음 |
| 계정 삭제 경로 | `https://koreayjk.github.io/imessenger/delete-account.html` ✅ 이미 살아 있음 |
| 대상 연령 | 학생이 쓰므로 **'어린이 대상'** 여부를 신중히 고르세요 |

> ⚠️ **데이터 보안 설문은 실제 코드와 일치해야 합니다.**
> TCS 는 이름·생년월일·이메일·사진·보호자 연락처를 모읍니다.
> 불일치가 적발되면 앱이 내려갑니다.

---

## 5. 나중에 도메인을 사시면

앱의 시작 주소가 바뀌므로 **새 도메인으로 assetlinks 를 다시 확인시키고 앱을 업데이트**해야 합니다.
사실 생각이 있으시면 지금 정하시는 편이 번거로움이 적습니다.
