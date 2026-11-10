#!/bin/bash
# Runs the player's nightly-report.sh three times in a scratch TMPDIR:
#  A. with report.tmp pre-planted as a symlink to a victim file (under umask 000),
#  B. with malformed data, so the data check fails halfway,
#  C. (during A) a logging wrapper around awk/sort/head/cp records the modes of every
#     regular file in TMPDIR whenever the script calls them.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected-report ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f nightly-report.sh ] || { echo "❌ nightly-report.sh is missing"; exit 1; }
[ "$(sha256sum < data/sales.csv)" = "$(cat .lm-state/data.sha)" ] || { echo "❌ data/sales.csv was changed, the script must be fixed instead"; exit 1; }
if grep -qE '\$\$|\$\{\$\}|\$RANDOM|\$\(date' nightly-report.sh; then
  echo "❌ the temp file name is still guessable (PID, RANDOM or date): let a tool choose it"; exit 1
fi

t=$(mktemp -d "${TMPDIR:-/tmp}/lm-tmpchk.XXXXXX") || exit 1
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/tmp" "$t/stubs"
victim="$t/victim.txt"; echo "PRECIOUS" > "$victim"
for tool in awk sort head cp; do
  real=$(command -v "$tool")
  printf '#!/bin/bash\nfind "$LM_TMP" -type f -printf "%%m\\n" >> "$LM_LOG" 2>/dev/null\nexec %s "$@"\n' "$real" > "$t/stubs/$tool"
  chmod 755 "$t/stubs/$tool"
done
plant() { rm -rf "$t/tmp"; mkdir -p "$t/tmp"; ln -s "$victim" "$t/tmp/report.tmp"; }

# A: good data, symlink planted, hostile umask
plant; : > "$t/modes"
( umask 000; TMPDIR="$t/tmp" LM_TMP="$t/tmp" LM_LOG="$t/modes" PATH="$t/stubs:$PATH" \
    timeout 20 bash nightly-report.sh data/sales.csv "$t/out.txt" > "$t/a.log" 2>&1 )
rc=$?
[ "$(cat "$victim")" = "PRECIOUS" ] || { echo "❌ the script followed a symlink planted at report.tmp and overwrote another file"; exit 1; }
[ "$rc" -eq 0 ] || { echo "❌ the script fails on good data (exit $rc): $(head -1 "$t/a.log")"; exit 1; }
cmp -s "$t/out.txt" .lm-state/expected-report || { echo "❌ the report content is not the same as before the change"; exit 1; }
[ -s "$t/modes" ] || { echo "❌ no temporary file was seen while the script was working: it must keep using one"; exit 1; }
if grep -qvx 600 "$t/modes"; then
  echo "❌ the temporary file is readable by others while it exists (mode $(grep -vx 600 "$t/modes" | head -1))"; exit 1
fi
left=$(find "$t/tmp" -mindepth 1 ! -name report.tmp | head -1)
[ -z "$left" ] || { echo "❌ a temp file ($(basename "$left")) is left in TMPDIR after a successful run"; exit 1; }

# B: malformed data, the data check fails midway
plant; printf 'id,customer,amount\n1,acme,10.00\nthis line is broken\n' > "$t/bad.csv"
( TMPDIR="$t/tmp" timeout 20 bash nightly-report.sh "$t/bad.csv" "$t/out2.txt" > "$t/b.log" 2>&1 )
rc=$?
[ "$rc" -ne 0 ] || { echo "❌ the script reports success on malformed data: failures must still stop it"; exit 1; }
[ "$(cat "$victim")" = "PRECIOUS" ] || { echo "❌ the script overwrote another file through the symlink"; exit 1; }
left=$(find "$t/tmp" -mindepth 1 ! -name report.tmp | head -1)
[ -z "$left" ] || { echo "❌ when the data check fails, a temp file ($(basename "$left")) is left behind: cleanup must run on failure too"; exit 1; }
echo "✅ safe temp file, private while it exists, removed on success and on failure"
exit 0
