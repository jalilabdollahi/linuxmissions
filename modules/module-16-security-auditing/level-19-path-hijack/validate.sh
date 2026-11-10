#!/bin/bash
# Runs srv/rotate-keys.sh with the cron job's PATH (writable dir first, empty element) from
# a working directory that also holds fakes, where fake tar/gzip/date/mkdir/chmod/rm/ls/cat
# in both places log to a file and do nothing. The fakes must never run, the output must be
# right and the archive must contain the keys. hijack.txt must name the writable PATH dir.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/badpath ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f srv/rotate-keys.sh ] || { echo "❌ srv/rotate-keys.sh is missing"; exit 1; }
badpath=$(cat .lm-state/badpath); writable=$(cat .lm-state/writable)

t=$(mktemp -d "${TMPDIR:-/tmp}/lm-pathchk.XXXXXX") || exit 1
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/cwd" "$t/archive" "$t/keys"
cp srv/keys/* "$t/keys/"
for d in "$SANDBOX/$writable" "$t/cwd"; do
  mkdir -p "$d"
  for tool in tar gzip date mkdir chmod rm ls cat cp mv; do
    printf '#!/bin/sh\necho "%s" >> "%s"\nexit 0\n' "$tool" "$t/hijacked" > "$d/$tool"; chmod 755 "$d/$tool"
  done
done
out=$(cd "$t/cwd" && env -i HOME="$t" PATH="$badpath" /bin/bash "$SANDBOX/srv/rotate-keys.sh" "$t/keys" "$t/archive" 2>&1); rc=$?
rm -f "$SANDBOX/$writable"/{tar,gzip,date,mkdir,chmod,rm,ls,cat,cp,mv}
if [ -s "$t/hijacked" ]; then
  echo "❌ a planted fake \`$(head -1 "$t/hijacked")\` ran instead of the real command: the script still trusts PATH"; exit 1
fi
[ "$rc" -eq 0 ] || { echo "❌ the script fails when run with the cron environment (exit $rc): $(echo "$out" | head -1)"; exit 1; }
stamp=$(printf '%(%Y%m%d)T' -1)
want=$(printf 'archive: keys-%s.tar.gz\nkeys archived: %s' "$stamp" "$(ls "$t/keys" | wc -l)")
[ "$out" = "$want" ] || { echo "❌ the script output changed: it must still print the archive name and the key count"; exit 1; }
arc="$t/archive/keys-$stamp.tar.gz"
/usr/bin/gzip -t "$arc" 2>/dev/null || { echo "❌ $arc is missing or not a valid gzip file"; exit 1; }
[ ! -e "$t/archive/keys-$stamp.tar" ] || { echo "❌ the uncompressed tar was left next to the archive"; exit 1; }
got=$(/usr/bin/tar -tzf "$arc" | grep -v '/$' | LC_ALL=C sort)
exp=$(ls "$t/keys" | sed 's|^|./|' | LC_ALL=C sort)
[ "$got" = "$exp" ] || { echo "❌ the archive does not contain exactly the key files"; exit 1; }

[ -s hijack.txt ] || { echo "❌ hijack.txt is missing or empty"; exit 1; }
norm=$(sed -e 's/\r$//' -e "s#^$SANDBOX/##" -e 's#^/##' -e 's#/*$##' hijack.txt | grep -v '^[[:space:]]*$' | sort -u)
[ "$norm" = "$writable" ] || { echo "❌ hijack.txt should name only the world-writable directory in the PATH (found: $(echo "$norm" | head -2 | tr '\n' ' '))"; exit 1; }
echo "✅ the script no longer trusts PATH (writable dir and current directory), output and archive are right"
exit 0
