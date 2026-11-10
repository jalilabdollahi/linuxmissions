#!/bin/bash
# Expected statuses are stored by setup.sh. quarantine/ must hold exactly the
# corrupted file (identical bytes), release/ must still hold the five good files
# unchanged, and verify.log must carry sha256sum's own "name: OK/FAILED" line for
# each of the six downloaded files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
bad=$(cat .lm-state/bad)

for f in $(awk '$2 == "OK" { print $1 }' .lm-state/expected); do
  if [ -f "quarantine/$f" ]; then echo "❌ $f verified correctly but was moved to quarantine/"; exit 1; fi
  if [ ! -f "release/$f" ]; then echo "❌ the good file $f is no longer in release/"; exit 1; fi
  if [ "$(sha "release/$f")" != "$(awk -v n="$f" '$1 == n { print $2 }' .lm-state/hashes)" ]; then
    echo "❌ the good file $f was modified"; exit 1
  fi
done
q=$(ls -A quarantine 2>/dev/null)
if [ -z "$q" ]; then
  if [ -f "release/$bad" ]; then echo "❌ quarantine/ is empty: the corrupted file is still in release/"; else echo "❌ quarantine/ is empty and a downloaded file is missing from release/"; fi
  exit 1
fi
if [ "$q" != "$bad" ]; then echo "❌ quarantine/ contains $(echo "$q" | head -1), which is not the corrupted file"; exit 1; fi
if [ -f "release/$bad" ]; then echo "❌ the corrupted file is in quarantine/ but a copy is still in release/"; exit 1; fi
if [ "$(sha "quarantine/$bad")" != "$(awk -v n="$bad" '$1 == n { print $2 }' .lm-state/hashes)" ]; then
  echo "❌ the file in quarantine/ was changed: move it, do not edit it"; exit 1
fi

if [ ! -f verify.log ]; then echo "❌ verify.log does not exist yet (save sha256sum's output in the sandbox folder)"; exit 1; fi
got=$(tr -d '\r' < verify.log | sed -n 's/^\(.*\): \(OK\|FAILED\)$/\1 \2/p' | LC_ALL=C sort)
want=$(LC_ALL=C sort .lm-state/expected)
if [ "$got" != "$want" ]; then
  if [ -z "$got" ]; then
    echo "❌ verify.log has no lines like \"file: OK\" or \"file: FAILED\" (it must be sha256sum's own output)"
  else
    n=$(printf '%s\n' "$got" | grep -c .)
    [ "$n" != 6 ] && echo "❌ verify.log has verdicts for $n files, expected 6 (every downloaded file covered by SHA256SUMS, and no others)" \
                  || echo "❌ verify.log disagrees with the real state of the files"
  fi
  exit 1
fi
echo "✅ all six downloads were verified, the corrupted one is in quarantine/ and the rest is untouched"
exit 0
