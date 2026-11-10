#!/bin/bash
# Run promote.sh on the three sample builds and on three builds made now (bad signature, bad
# checksum, bad layout, each with a random variant and a version newer than prod).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f promote.sh ]; then
  echo "❌ promote.sh does not exist yet"
  exit 1
fi
PROD=$(cat prod/VERSION)
rm -rf .lm/hidden; mkdir -p .lm/hidden
sigv=(badkey tampered); layv=(mode notop junk owner)
python3 "$HERE/mkbuild.py" .lm/hidden/h1 "1.10.$((RANDOM % 9))" --sig "${sigv[$((RANDOM % 2))]}" || exit 1
python3 "$HERE/mkbuild.py" .lm/hidden/h2 "1.11.$((RANDOM % 9))" --checksum bad || exit 1
python3 "$HERE/mkbuild.py" .lm/hidden/h3 "1.10.$((RANDOM % 9))" --layout "${layv[$((RANDOM % 4))]}" || exit 1
{
  cat .lm/expected.txt | while read -r n v g; do echo "$SANDBOX/builds/$n $v $g"; done
  echo "$SANDBOX/.lm/hidden/h1 REJECT signature"
  echo "$SANDBOX/.lm/hidden/h2 REJECT checksum"
  echo "$SANDBOX/.lm/hidden/h3 REJECT layout"
} > .lm/cases.txt
before=$(find builds .lm/hidden prod keys -type f -exec sha256sum {} + | sort | sha256sum)
fail=""
while read -r dir verdict gate; do
  label=$(basename "$dir")
  case "$dir" in *hidden*) label="a hidden build that fails the $gate gate" ;; *) label="sample $label" ;; esac
  out=$(cd / && timeout 20 bash "$SANDBOX/promote.sh" "$dir" 2>/dev/null); rc=$?
  lines=$(printf '%s\n' "$out" | grep -c .)
  if [ "$verdict" = PROMOTE ]; then
    if [ "$out" != "PROMOTE" ] || [ $rc -ne 0 ]; then
      echo "❌ $label should be promoted: got '$(echo "$out" | head -1 | cut -c1-80)' with exit status $rc"
      exit 1
    fi
  else
    if [ $rc -eq 0 ]; then
      echo "❌ $label must be rejected, but promote.sh exited 0 (output: '$(echo "$out" | head -1 | cut -c1-80)')"
      exit 1
    fi
    first=$(printf '%s\n' "$out" | head -1)
    if ! printf '%s\n' "$first" | grep -qE "^REJECT: $gate( .*)?$"; then
      echo "❌ $label must give 'REJECT: $gate', got '$(echo "$first" | cut -c1-80)'"
      exit 1
    fi
    if [ "$lines" -ne 1 ]; then
      echo "❌ promote.sh must print exactly one line, it printed $lines for $label"
      exit 1
    fi
  fi
done < .lm/cases.txt
after=$(find builds .lm/hidden prod keys -type f -exec sha256sum {} + | sort | sha256sum)
if [ "$before" != "$after" ]; then
  echo "❌ promote.sh changed files in builds/, prod/ or keys/: a gate must not modify anything"
  exit 1
fi
echo "✅ promote.sh gives the right verdict and reason for all six builds (3 samples, 3 made just now)"
