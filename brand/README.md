# TCS 브랜드 자산

개선창에서 고른 ⑫안(불꽃 엠블럼 + 세로 락업)을 벡터로 다시 그린 것입니다.
AI 가 그린 그림이 아니라 **좌표로 그린 도형**이라 아무리 키워도 안 깨집니다.

## 색

| 이름 | 값 | 쓰는 곳 |
|---|---|---|
| 남색 | `#1d3a5f` | 글자·받침·배경 타일 |
| 금색 | `#C9A227` | 불꽃·밑줄 |
| 흰색 | `#ffffff` | 어두운 배경 위 글자 |

글꼴은 **Montserrat** (ExtraBold = TCS, Medium = 태그라인). 글자는 이미
도형으로 변환돼 있어서 글꼴을 설치하지 않아도 똑같이 보입니다.

## 파일

| 파일 | 어디에 |
|---|---|
| `tcs-logo-vertical.svg` / `-dark.svg` | 안내문·증명서·명함. 흰 바탕 / 어두운 바탕 |
| `tcs-logo-horizontal.svg` / `-dark.svg` | 문서 머리글·웹 상단 |
| `tcs-emblem.svg` / `-dark.svg` | 불꽃만. 아주 작은 자리나 장식 |
| `tcs-icon.svg` | 앱 아이콘 (남색 타일 + 불꽃 + TCS) |
| `tcs-icon-maskable.svg` | 안드로이드 maskable — 바깥이 잘려도 괜찮게 여백을 더 둠 |
| `tcs-favicon.svg` | 32px 처럼 아주 작을 때. 불꽃을 빼고 글자만 |

저장소 맨 위의 `tcs_icon-192/512.png`, `tcs_icon-maskable-*.png`,
`favicon.png`, `apple-touch-icon.png`, `tcs_logo.png` 는 여기 SVG 에서
뽑은 것입니다.

## 다시 뽑기

```bash
python3 brand/build.py        # SVG 다시 만들기
node /tmp/.../png.js          # PNG 다시 뽑기 (크기 목록은 그 파일 안)
```

`build.py` 가 `emblem.py`(불꽃 모양)와 `txt.py`(글자를 도형으로)를 씁니다.
Montserrat `.ttf` 두 개가 있어야 합니다 (Google Fonts, OFL).

## 쓸 때 지킬 것

- **태그라인(TOTAL CARE SYSTEM)은 작은 자리에 쓰지 마세요.** 높이 40px
  아래로 가면 읽히지 않습니다. 그 자리에는 아이콘이나 엠블럼을 쓰세요.
- 남색 배경 위에는 **`-dark` 버전**을 쓰세요. 남색 타일을 올리면 묻힙니다.
- 로고 둘레에 **불꽃 높이의 반만큼** 빈 자리를 두세요.
- 색을 바꾸거나 늘이거나 기울이지 마세요.
