# assetlinks.json — 아직 비어 있습니다

지금은 `[]` 입니다. 이 파일이 **200 으로 열리는지 확인하는 용도**로 먼저 올려 둡니다.
(GitHub Pages 가 점으로 시작하는 폴더를 제대로 서비스하는지 검증)

앱을 Play Console 에 올린 뒤, 지문 두 개를 채워야 TWA 주소창이 사라집니다.

## 채우는 법

1. **Play 앱 서명 키 지문**
   `Play Console → 테스트 및 출시 → 앱 무결성 → "Google Play로 보호됨" → 앱 서명`
   → "앱 서명 키 인증서" 의 SHA-256 인증서 지문

2. **업로드 키 지문**
   PWABuilder 가 준 zip 안 `signing-key-info.txt`

3. 아래 형식으로 `assetlinks.json` 을 채웁니다.

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "app.<확정한이름>.twa",
    "sha256_cert_fingerprints": [
      "<Play 앱 서명 키 지문>",
      "<업로드 키 지문>"
    ]
  }
}]
```

4. 배포 후 확인

```bash
curl -s https://<도메인>/.well-known/assetlinks.json | jq .
```

Google 검증기:
`https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://<도메인>&relation=delegate_permission/common.handle_all_urls`

> 지문은 여러 개 넣어도 됩니다. 하나라도 맞으면 통과하므로 확신이 없으면 다 넣으세요.
