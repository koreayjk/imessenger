# Supabase 프로젝트 통째 이전 가이드 (데이터까지)

구 프로젝트 → 새 프로젝트로 **스키마 + 데이터 + 로그인 계정**을 옮깁니다.

- 구(OLD) project-ref: `epzzpabzhahguulnsttp`
- 신(NEW) project-ref: `bbfvnmlrdtzmcwfadjqw`

> ⚠️ 이 작업은 **당신 컴퓨터(터미널)** 에서 직접 실행합니다. 두 프로젝트의 **DB 비밀번호**가 필요합니다.
> (Claude/앱 코드에서는 실행 불가 — DB 직접 접속이 필요한 작업입니다.)

---

## 0. 준비물
1. **Supabase CLI** 설치 → `npm i -g supabase` (또는 `brew install supabase/tap/supabase`)
2. **PostgreSQL 클라이언트**(psql) 설치 — Postgres 15 이상 권장
3. 각 프로젝트의 **DB 접속 문자열(URI)**:
   - Supabase 대시보드 → 해당 프로젝트 → **Project Settings → Database → Connection string → URI**
   - 형식: `postgresql://postgres:[비밀번호]@db.[project-ref].supabase.co:5432/postgres`

```bash
# 본인 비밀번호로 채우세요
OLD="postgresql://postgres:[구-DB비번]@db.epzzpabzhahguulnsttp.supabase.co:5432/postgres"
NEW="postgresql://postgres:[신-DB비번]@db.bbfvnmlrdtzmcwfadjqw.supabase.co:5432/postgres"
```

---

## 1. 구 프로젝트에서 덤프 뽑기
```bash
# 역할(roles)
supabase db dump --db-url "$OLD" -f roles.sql --role-only
# 스키마(테이블 구조)
supabase db dump --db-url "$OLD" -f schema.sql
# 데이터
supabase db dump --db-url "$OLD" -f data.sql --use-copy --data-only
```
> 기본 덤프는 스키마만 받습니다. 데이터·역할은 `--data-only`, `--role-only`로 따로 받아야 합니다.

## 2. 새 프로젝트로 복원
```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$NEW"
```
> `session_replication_role = replica` 는 복원 중 트리거를 꺼서 **auth 비밀번호 이중 암호화** 등의 문제를 막습니다. 꼭 포함하세요.

이 과정에 **`auth.users`(로그인 계정)도 함께 이전**됩니다. → 기존 사용자들이 같은 이메일/비밀번호로 로그인 가능.

---

## 3. 따로 챙겨야 하는 것 (덤프에 안 담기는 것)

### 3-1. Storage 파일 (이미지/첨부)
DB 덤프에는 **파일 메타데이터만** 담기고 **실제 파일**은 안 옮겨집니다. 버킷 파일을 따로 복사하세요.
```bash
# 최신 Supabase CLI의 storage 복사 (버킷별로)
supabase storage cp -r "ss://<버킷명>" ./storage-backup --project-ref epzzpabzhahguulnsttp
supabase storage cp -r ./storage-backup "ss://<버킷명>" --project-ref bbfvnmlrdtzmcwfadjqw
```
> 버킷 목록은 대시보드 → Storage에서 확인. (CLI 버전에 따라 명령이 다르면 rclone+S3 자격증명 방식도 가능)

### 3-2. Edge Function (모의고사 분석)
```bash
supabase functions deploy analyze-mockexam --project-ref bbfvnmlrdtzmcwfadjqw --no-verify-jwt
supabase secrets set GEMINI_API_KEY=발급받은_키 --project-ref bbfvnmlrdtzmcwfadjqw
```

### 3-3. auth/storage 스키마 커스텀 (있다면)
구 프로젝트의 auth·storage 스키마에 직접 만든 **트리거·RLS**가 있으면 별도로 다시 적용하세요.

### 3-4. 커스텀 LOGIN 역할
LOGIN 속성의 커스텀 역할을 만들었다면, 새 프로젝트에서 **비밀번호를 수동으로 다시 설정**해야 합니다.

---

## 4. 마무리 확인
- [ ] 새 프로젝트 대시보드 → Table Editor에 테이블·데이터가 보이는지
- [ ] 라이브 앱에서 **기존 계정으로 로그인** 되는지
- [ ] 이미지/첨부가 보이는지 (Storage 이전 확인)
- [ ] 모의고사 분석(Edge Function) 동작
- [ ] 앱의 `SUPABASE_URL`/`KEY`는 이미 새 프로젝트로 교체됨 ✅ (코드 반영 완료)

---

### 참고 문서
- Backup and Restore using the CLI — https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- Migrating within Supabase — https://supabase.com/docs/guides/platform/migrating-within-supabase
