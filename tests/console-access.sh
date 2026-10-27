#!/usr/bin/env bash
# Regression probe for the nginx public-console block. Prints only PASS/FAIL lines and status codes.
set -u

HOST="${HOST:-appflowy.hectormr.com}"
SIBLING_HOST="${SIBLING_HOST:-yax.hectormr.com}"
MODE="${1:-public}"

usage() {
  cat <<USAGE
Usage: console-access.sh [public|origin] | --help

  public   (default) Test through public DNS/TLS with normal certificate validation.
  origin   Test the local Traefik directly: --noproxy '*' (configured proxies are
           ignored so --resolve really pins the origin), --resolve
           HOST:{80,443}:\$ORIGIN_IP and --insecure. Certificate validation is
           skipped ONLY for this local routing check.

Environment:
  HOST          Guarded host (default appflowy.hectormr.com)
  SIBLING_HOST  Unguarded host that must stay healthy (default yax.hectormr.com)
  ORIGIN_IP     Origin address for origin mode (default 127.0.0.1)
  CONNECT_TO    curl --connect-timeout seconds (default 5)
  MAX_TIME      curl --max-time seconds per request (default 10)

Exit status 0 when every assertion passes, 1 on any failure, 2 on bad usage.
Requests use --path-as-is with no retries; bodies/cookies are discarded.
Only the HTTP console check follows redirects (up to three) to test final denial.
USAGE
}

case "$MODE" in
  -h|--help) usage; exit 0 ;;
  public|origin) ;;
  *) usage >&2; exit 2 ;;
esac

ORIGIN_IP="${ORIGIN_IP:-127.0.0.1}"
# Curl budgets apply to each check, not to the complete script.
CONNECT_TO="${CONNECT_TO:-5}"
MAX_TIME="${MAX_TIME:-10}"
fail=0

# check <expected> <label> <scheme> <host> <path> [extra curl args...]
check() {
  local want="$1" label="$2" scheme="$3" host="$4" path="$5"
  shift 5
  local args=(-sS -o /dev/null -w '%{http_code}' --path-as-is --retry 0
    --connect-timeout "$CONNECT_TO" --max-time "$MAX_TIME")
  if [ "$MODE" = origin ]; then
    args+=(--noproxy '*' --insecure --resolve "$host:80:$ORIGIN_IP" --resolve "$host:443:$ORIGIN_IP")
  fi
  local got rc
  if got="$(curl "${args[@]}" "$@" "$scheme://$host$path")"; then
    rc=0
  else
    rc=$?
  fi
  got="${got:-000}"
  if [ "$rc" -ne 0 ]; then
    echo "FAIL $label: curl exit $rc (http $got)"
    fail=1
    return
  fi
  if [ "$got" = "$want" ]; then
    echo "PASS $label: $got"
  else
    echo "FAIL $label: expected $want got $got"
    fail=1
  fi
}

# Console must be denied (403) on every path shape nginx would route to /console.
check 403 "console exact"            https "$HOST" /console
check 403 "console trailing slash"   https "$HOST" /console/
check 403 "console login"            https "$HOST" /console/login
check 403 "console repeated slash"   https "$HOST" //console/login
check 403 "console encoded first char" https "$HOST" /%63onsole/login
# A Next.js 404 here still exposes the admin runtime; require an actual denial.
check 403 "console encoded leading slash" https "$HOST" /%2fconsole/login
check 403 "console encoded separator" https "$HOST" /console%2flogin
check 403 "console encoded dot slash" https "$HOST" /.%2fconsole/login
check 403 "console encoded parent slash" https "$HOST" /x/..%2fconsole/login
check 403 "console forwarded spoof"  https "$HOST" /console/login \
  -H 'X-Forwarded-For: 127.0.0.1' -H 'X-Real-IP: 127.0.0.1'
check 403 "console http final denial" http "$HOST" /console/login \
  --location --max-redirs 3

# Pin this deployment's baseline: root redirects (302), auth/API health is 200.
check 302 "root"            https "$HOST" /
check 200 "gotrue health"   https "$HOST" /gotrue/health
check 200 "api health"      https "$HOST" /api/health

# Sibling host on the same proxy must be unaffected.
check 200 "sibling host"    https "$SIBLING_HOST" /

if [ "$fail" -eq 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$fail"
