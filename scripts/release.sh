#!/usr/bin/env bash
# One-step release: quick checks, commit, push to main and wait for the VPS
# webhook deploy (it builds the web version, the signed APK and the download
# page in the Docker image), then verify the live site.
#   scripts/release.sh "Commit message"   # commits all changes, then releases
#   scripts/release.sh                    # releases what is already committed
#   FULL=1 scripts/release.sh "…"         # full test suite instead of unit tests
#   SKIP_TESTS=1 scripts/release.sh "…"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://godot-park.ironstrike.de"
LOGS="$HOME/clones/config/logs"
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
cd "$ROOT"

[[ "$(git branch --show-current)" == main ]] || die "not on main"

if [[ "${SKIP_TESTS:-0}" != 1 ]]; then
  log "Tests"
  rc=0
  if [[ "${FULL:-0}" == 1 ]]; then out=$(scripts/test.sh 2>&1) || rc=$?
  else out=$(scripts/test.sh unit 2>&1) || rc=$?; fi
  echo "$out" | grep -E "tests,|SMOKE|FAIL|SCRIPT ERROR|stuck|passed" | tail -8
  [[ $rc == 0 ]] || die "tests failed"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  [[ $# -ge 1 ]] || die "uncommitted changes: pass a commit message"
  git add -A
  git commit -q -m "$1"
fi

git fetch -q origin main
[[ -z "$(git log --oneline HEAD..origin/main)" ]] || die "origin/main has commits you don't have; pull first"
sha="$(git rev-parse HEAD)"
if [[ "$(git rev-parse origin/main)" == "$sha" ]] && grep -q "\"sha\":\"$sha\".*\"status\":\"success\"" "$LOGS/deploys.jsonl" 2>/dev/null; then
  log "${sha:0:7} is already live"
else
  log "Push ${sha:0:7}: $(git log -1 --format=%s)"
  git push -q origin main
  log "Waiting for the deploy (builds web + APK, ~1–10 min)"
  for _ in $(seq 1 120); do
    line="$(grep "\"sha\":\"$sha\"" "$LOGS/deploys.jsonl" 2>/dev/null | grep '"finished"' | tail -1 || true)"
    [[ -n "$line" ]] && break
    sleep 10
  done
  [[ -n "$line" ]] || die "no finished deploy for ${sha:0:7} after 20 min (see https://deploy.ironstrike.de/dashboard)"
  if ! grep -q '"status":"success"' <<<"$line"; then
    logfile="$(sed -n 's/.*"log":"\([^"]*\)".*/\1/p' <<<"$line")"
    tail -30 "$LOGS/$logfile"
    die "deploy failed (log: $LOGS/$logfile)"
  fi
fi

log "Verify live site"
code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/")
[[ "$code" == 200 ]] || die "$URL/ answered $code"
meta="$(curl -s "$URL/download" | sed -n 's/.*class="meta">\(.*\)<\/p>.*/\1/p')"
apk_bytes="$(curl -sI "$URL/bank-frei.apk" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}')"
[[ "${apk_bytes:-0}" -gt 1000000 ]] || die "APK missing or too small ($apk_bytes bytes)"
log "Live: $URL  ·  Download: $URL/download  ·  $meta"
