#!/bin/bash
# There must be exactly one queued job, in queue b. Replay it the way atd
# does (empty environment, `sh jobfile` from /): reindex.sh must complete in
# app/ with DATA_DIR = <sandbox>/data, which only works if the job captured
# the right directory and environment when it was queued.
SANDBOX="$1"
SPOOL="$SANDBOX/var/spool/cron/atjobs"
cd "$SANDBOX" || exit 1

if [ "$(cksum < app/reindex.sh 2>/dev/null)" != "2072533695 689" ] ||
   [ "$(cksum < app/reindex.conf 2>/dev/null)" != "2969152913 65" ]; then
  echo "❌ app/reindex.sh or app/reindex.conf was changed; the fix is in how the job is queued (type reset to restore them)"
  exit 1
fi

jobs=()
for f in "$SPOOL"/*; do
  case "${f##*/}" in
    [a-zA-Z][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) jobs+=("$f") ;;
  esac
done
if [ ${#jobs[@]} -eq 0 ]; then
  echo "❌ nothing is queued yet (atq is empty)"
  exit 1
fi
if [ ${#jobs[@]} -gt 1 ]; then
  echo "❌ ${#jobs[@]} jobs are queued and atd would start every one of them; keep exactly one (atq, atrm)"
  exit 1
fi
job="${jobs[0]}"
name="${job##*/}"
num=$((16#${name:1:5}))
queue="${name:0:1}"
if [ "$queue" != b ]; then
  echo "❌ job $num is in queue $queue, so it starts at its time whatever the load; batch jobs go to queue b"
  exit 1
fi
if ! grep -q 'reindex\.sh' "$job"; then
  echo "❌ job $num does not run reindex.sh (at -c $num shows what it runs)"
  exit 1
fi

# Replay the job like atd: no inherited environment, started from /.
OUT="$(mktemp)"
trap 'rm -f "$OUT"; rm -rf "$SANDBOX/data/index"' EXIT
rm -rf "$SANDBOX/data/index"
(cd / && env -i PATH=/usr/bin:/bin timeout 20 sh "$job" > "$OUT" 2>&1)
rc=$?
idx="$SANDBOX/data/index/search.idx"
if [ $rc -ne 0 ] || [ ! -s "$idx" ]; then
  why="$(grep -m1 -E 'reindex|DATA_DIR|No such|not found|inaccessible' "$OUT")"
  echo "❌ when atd starts job $num, reindex.sh fails${why:+: $why} (at -c $num shows the directory and variables the job will get)"
  exit 1
fi
src="$(sed -n '1s/^# index products-v3 built from //p' "$idx")"
case "$src" in
  /*) ;;
  *) echo "❌ job $num ran with DATA_DIR='${src%/products.csv}', a relative path; use the full path of data/"
     exit 1 ;;
esac
want="$(cd "$SANDBOX/data" && pwd -P)"
got="$(cd "$(dirname "$src")" 2>/dev/null && pwd -P)"
if [ "$got" != "$want" ]; then
  echo "❌ job $num ran with DATA_DIR=${src%/products.csv}, not this sandbox's data directory"
  exit 1
fi
if [ "$(grep -c '^ *[0-9]' "$idx")" -lt 10 ]; then
  echo "❌ job $num ran, but the index it built is incomplete"
  exit 1
fi
echo "✅ job $num waits in the batch queue and will rebuild the index in app/ with DATA_DIR=${src%/products.csv}"
exit 0
