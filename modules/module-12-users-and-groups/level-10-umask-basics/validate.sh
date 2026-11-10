#!/bin/bash
# Run publish.sh twice into fresh directories, with the caller's umask set to 077
# and to 022: every file it creates must be 664 and every directory 775, the
# report must still have its content, and the script must not chmod afterwards.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f publish.sh ] || ! head -n 1 publish.sh | grep -q '^#!'; then
  echo "❌ publish.sh is missing or lost its #! line"
  exit 1
fi
if grep -Ev '^[[:space:]]*#' publish.sh | grep -Eq '(^|[^[:alnum:]_.-])(chmod|install|setfacl|chgrp)([^[:alnum:]_-]|$)|mkdir[^|;&]* -m|mkdir[^|;&]*--mode'; then
  echo "❌ publish.sh fixes modes by hand (chmod/install/mkdir -m); set the process's umask once instead, so everything it creates comes out right"
  exit 1
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/lm-umask.XXXXXX") || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT

# the data the report is built from
total=$(cat data/*.log | wc -l | tr -d ' ')
errors=$(awk '$9 ~ /^5/' data/*.log | wc -l | tr -d ' ')
EXPECT="2026-w45
2026-w45/raw
2026-w45/summary.txt
publish.log"
for f in data/access-*.log; do b=${f#data/access-}; EXPECT="$EXPECT
2026-w45/raw/${b%.log}.sorted"; done
EXPECT=$(printf '%s\n' "$EXPECT" | LC_ALL=C sort)

for um in 077 022; do
  out="$T/reports-$um"
  after=$( ( umask "$um"; bash "$SANDBOX/publish.sh" "$out" >/dev/null 2>"$T/err"; rc=$?; echo "$rc $(umask)" ) )
  rc=${after%% *}
  if [ "$rc" != 0 ]; then
    echo "❌ publish.sh fails when run (exit $rc): $(head -n 1 "$T/err")"
    exit 1
  fi
  if [ "$((8#${after#* }))" != "$((8#$um))" ]; then
    echo "❌ the caller's umask changed to ${after#* }: only the script's own process may set its umask"
    exit 1
  fi
  LIST=$(cd "$out" && find . -mindepth 1 | sed 's|^\./||' | LC_ALL=C sort)
  if [ "$LIST" != "$EXPECT" ]; then
    echo "❌ publish.sh no longer creates the same report files (expected summary.txt, raw/*.sorted and publish.log under 2026-w45)"
    exit 1
  fi
  if ! grep -qx "total requests: $total" "$out/2026-w45/summary.txt" || ! grep -qx "server errors: $errors" "$out/2026-w45/summary.txt"; then
    echo "❌ summary.txt no longer has the right totals"
    exit 1
  fi
  # the output directory itself, then everything in it
  m=$(stat -c %a "$out")
  if [ "$m" != 775 ]; then
    echo "❌ with a caller umask of $um, the report directory itself is mode $m, expected 775"
    exit 1
  fi
  while IFS= read -r p; do
    m=$(stat -c %a "$out/$p")
    if [ -d "$out/$p" ]; then want=775; else want=664; fi
    if [ "$m" != "$want" ]; then
      echo "❌ with a caller umask of $um, $p comes out as mode $m, expected $want (the team shares this directory)"
      exit 1
    fi
  done <<< "$LIST"
done
echo "✅ with caller umasks 077 and 022 the reports come out 664 and the directories 775, with no chmod in the script"
exit 0
