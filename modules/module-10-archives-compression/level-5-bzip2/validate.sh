#!/bin/bash
# Both deliverables must really be bzip2 (BZh magic), with the right content;
# audit.log must still be there.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/audit.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
magic() { head -c 3 "$1" | od -An -c | tr -d ' \n'; }

if [ ! -f audit.log ]; then
  echo "❌ audit.log is gone; bzip2 deletes the original unless you keep it (get it back with bunzip2 -k, or type 'reset')"
  exit 1
fi
if [ "$(cksum < audit.log)" != "$(cat .lm-state/audit.sum)" ]; then
  echo "❌ audit.log was changed; type 'reset' to get the original back"
  exit 1
fi
FILES=$(cd ledger 2>/dev/null && find . -type f | sed 's|^\./|ledger/|' | LC_ALL=C sort)
if [ "$(printf '%s\n' "$FILES" | grep -c .)" -ne 14 ]; then
  echo "❌ ledger/ was changed (it should hold 14 files); type 'reset'"
  exit 1
fi

T=outbox/ledger-2025.tar.bz2
if [ ! -f "$T" ]; then
  echo "❌ $T does not exist"
  exit 1
fi
if [ "$(magic "$T")" != "BZh" ]; then
  if [ "$(head -c 2 "$T" | od -An -tx1 | tr -d ' \n')" = "1f8b" ]; then
    echo "❌ $T is still gzip data with a .bz2 name (try: file $T); the transfer system reads the content"
  else
    echo "❌ $T is not bzip2 data (try: file $T)"
  fi
  exit 1
fi
if ! members=$(bzip2 -dc "$T" 2>/dev/null | tar -tf - 2>/dev/null); then
  echo "❌ $T is bzip2, but it does not hold a tar archive"
  exit 1
fi
bad=$(printf '%s\n' "$members" | sed 's|^\./||' | grep -v -e '^ledger/' -e '^ledger$' | head -1)
if [ -n "$bad" ]; then
  echo "❌ $T holds '$bad'; every member should be inside ledger/"
  exit 1
fi
got=$(printf '%s\n' "$members" | sed 's|^\./||' | grep -v '/$' | grep -vx 'ledger' | LC_ALL=C sort)
if [ "$got" != "$FILES" ]; then
  echo "❌ $T holds $(printf '%s\n' "$got" | grep -c .) file(s); it should hold all $(printf '%s\n' "$FILES" | grep -c .) files of ledger/"
  exit 1
fi
for f in $FILES; do
  if ! bzip2 -dc "$T" | tar -xOf - "$f" 2>/dev/null | cmp -s - "$f"; then
    if ! bzip2 -dc "$T" | tar -xOf - "./$f" 2>/dev/null | cmp -s - "$f"; then
      echo "❌ $f inside $T differs from ledger/"
      exit 1
    fi
  fi
done

A=outbox/audit.log.bz2
if [ ! -f "$A" ]; then
  echo "❌ $A does not exist yet"
  exit 1
fi
if [ "$(magic "$A")" != "BZh" ]; then
  echo "❌ $A is not bzip2 data (try: file $A)"
  exit 1
fi
if ! bzip2 -dc "$A" 2>/dev/null | cmp -s - audit.log; then
  echo "❌ $A does not unpack to audit.log"
  exit 1
fi
echo "✅ both files in outbox/ are real bzip2 and audit.log is still in place"
exit 0
