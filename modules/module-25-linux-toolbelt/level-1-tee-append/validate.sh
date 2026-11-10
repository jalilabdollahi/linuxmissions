#!/bin/bash
# audit.log = original history (byte for byte) + exactly one run of the script,
# stdout and stderr interleaved as they were printed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f audit.log ]; then echo "❌ audit.log is missing"; exit 1; fi
if [ "$(cksum < maintenance.sh 2>/dev/null)" != "$(cat .lm-state/script.sum)" ]; then
  echo "❌ maintenance.sh was changed; type 'reset' and leave the script alone"
  exit 1
fi
orig=.lm-state/audit.orig
size=$(wc -c < "$orig" | tr -d ' ')
if ! head -c "$size" audit.log | cmp -s - "$orig"; then
  echo "❌ the old history is not intact at the start of audit.log (it was overwritten or changed)"
  exit 1
fi
added=$(mktemp "$SANDBOX/.lm-state/added.XXXXXX"); expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX")
trap 'rm -f "$added" "$expect"' EXIT
tail -c +"$((size + 1))" audit.log > "$added"
bash ./maintenance.sh > "$expect" 2>&1

if [ ! -s "$added" ]; then echo "❌ the history is safe, but nothing was added after it yet"; exit 1; fi
if cmp -s "$added" "$expect"; then
  echo "✅ audit.log keeps its $(wc -l < "$orig" | tr -d ' ') old lines and ends with this run's full output"
  exit 0
fi
want_w=$(grep -c '^WARN' "$expect"); got_w=$(grep -c '^WARN' "$added")
if [ "$got_w" -lt "$want_w" ]; then
  echo "❌ only $got_w of the $want_w WARN lines reached audit.log: the script's warnings go to stderr, which a pipe does not carry by itself"
elif [ "$(wc -c < "$added")" -gt "$(wc -c < "$expect")" ]; then
  echo "❌ audit.log has more than one run appended after the old history"
else
  echo "❌ what was appended differs from one run's output (missing lines, or lines in the wrong order)"
fi
exit 1
