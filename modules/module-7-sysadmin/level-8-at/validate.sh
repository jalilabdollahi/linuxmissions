#!/bin/bash
SANDBOX="$1"
SPOOL="$SANDBOX/var/spool/at"
SANDBOX_REAL="$(cd "$SANDBOX" && pwd -P)"

if [ ! -d "$SPOOL" ]; then
  echo "❌ the at spool (var/spool/at) is missing; use reset to start over"
  exit 1
fi

# Job 2 (certificate rotation) is unrelated and must survive.
if [ ! -f "$SPOOL/job2" ] || [ "$(sed -n '1p;3,$p' "$SPOOL/job2")" != "$(printf 'time=2024-04-10 02:00\n./rotate-certs.sh')" ]; then
  echo "❌ job 2 (rotate-certs.sh) was removed or changed; only touch the cleanup job"
  exit 1
fi

# Does a job body run this sandbox's cleanup.sh and nothing else?
runs_cleanup() {
  local f="$1" cwd body first
  cwd="$(sed -n 's/^cwd=//p' "$f")"
  body="$(sed '1,2d' "$f" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#')"
  [ "$(printf '%s\n' "$body" | grep -c .)" -eq 1 ] || return 1
  body="$(printf '%s' "$body" | sed -e "s|\${SANDBOX}|$SANDBOX|g" -e "s|\$SANDBOX|$SANDBOX|g")"
  set -f
  # shellcheck disable=SC2086
  set -- $body
  set +f
  case "$1" in sh|bash|/bin/sh|/bin/bash|/usr/bin/bash) shift ;; esac
  first="$1"; shift
  case "$first" in
    /*) ;;
    */*) first="$cwd/$first" ;;
    *) [ "${body#sh }" != "$body" ] || [ "${body#bash }" != "$body" ] || return 1   # bare name: not in PATH
       first="$cwd/$first" ;;
  esac
  [ "$(cd "$(dirname "$first")" 2>/dev/null && pwd -P)/$(basename "$first")" = "$SANDBOX_REAL/cleanup.sh" ] || return 1
  for w in "$@"; do
    case "$w" in '>'*|'>>'*|'2>'*|*'2>&1'|/*|*.log) ;; *) return 1 ;; esac
  done
  return 0
}

total=0; good=0; wrong_time=0
for f in "$SPOOL"/job*; do
  [ -f "$f" ] || continue
  [ "$f" = "$SPOOL/job2" ] && continue
  if grep -q 'cleanup' "$f"; then
    total=$((total + 1))
    if runs_cleanup "$f"; then
      if [ "$(sed -n 's/^time=//p' "$f")" = "2024-04-08 23:30" ]; then good=$((good + 1)); else wrong_time=$((wrong_time + 1)); fi
    else
      echo "❌ job ${f##*/job} does not just run this sandbox's cleanup.sh (check it with ./at -c ${f##*/job})"
      exit 1
    fi
  else
    echo "❌ job ${f##*/job} is not part of this task; remove it with atrm"
    exit 1
  fi
done

if [ "$wrong_time" -gt 0 ]; then
  echo "❌ a cleanup job is still queued for the wrong time (it would collide with the backup)"
  exit 1
fi
if [ "$good" -eq 0 ]; then
  echo "❌ no cleanup job is queued for tonight at 23:30 yet"
  exit 1
fi
if [ "$good" -gt 1 ]; then
  echo "❌ cleanup is queued $good times for 23:30; it should run once"
  exit 1
fi

echo "✅ the old cleanup job is gone and cleanup.sh runs once, tonight at 23:30"
exit 0
