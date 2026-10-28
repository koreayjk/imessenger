#!/usr/bin/env bash
#  🧪 시험 묶음 전부 돌리기 —  bash test/run.sh  (또는 한 묶음만: bash test/run.sh 학부모권한)
cd "$(dirname "$0")" || exit 1
fail=0
for f in ${1:+$1.js} ${1:-*.js}; do
  case "$f" in _*.js|stub.js) continue;; esac
  [ -f "$f" ] || continue
  printf '\n\033[1m══ %s ══\033[0m\n' "${f%.js}"
  node "$f" || fail=1
done
echo
[ $fail -eq 0 ] && echo "=== 전체 통과" || echo "=== 실패 있음"
exit $fail
