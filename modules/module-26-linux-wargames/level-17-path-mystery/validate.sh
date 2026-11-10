#!/bin/bash
SB="$1"; cd "$SB" || exit 1
OLD=$(cat .lm/old)
if ! sha256sum -c --quiet .lm/hashes >/dev/null 2>&1; then
  echo "❌ deploy-sim, the 2.4.1 install or the 1.x install was modified or removed: fix the shadows, not the tools"; exit 1
fi
out=$(./deploy-sim 2>&1)
if ! grep -qx 'deploy-sim: target=prod' <<<"$out"; then echo "❌ the CI job no longer sees DEPLOY_ENV=prod (a needed setting was lost)"; exit 1; fi
if ! grep -qx 'deployctl 2.4.1' <<<"$out"; then echo "❌ CI still reports: $(tail -1 <<<"$out")"; exit 1; fi
w=$(./deploy-sim --which 2>&1)
kind=$(sed -n 's/^kind=//p' <<<"$w")
path=$(sed -n 's/^path=//p' <<<"$w")
if [ "$kind" != "file" ] || [ "$path" != "$SB/opt/deployctl-2.4.1/bin/deployctl" ]; then
  echo "❌ the version is right but something still sits in front of the real 2.4.1 binary in the CI shell (resolves as '$kind')"; exit 1
fi
if [ ! -s shadows.txt ]; then echo "❌ shadows.txt is missing or empty"; exit 1; fi
expect=$(printf '%s\n' "$SB/home/ci/.ci_env" "$SB/home/ci/.local/bin/deployctl" "$SB/usr/local/bin/deployctl" | sort)
got=$(tr -d '\r' < shadows.txt | sed '/^[[:space:]]*$/d' | while read -r l; do readlink -m "$l"; done | sort -u)
if [ "$got" != "$expect" ]; then
  miss=$(comm -13 <(echo "$got") <(echo "$expect") | wc -l); extra=$(comm -23 <(echo "$got") <(echo "$expect") | wc -l)
  echo "❌ shadows.txt is off: $miss shadowing place(s) missing, $extra listed that did not affect the CI run (absolute paths, one per line)"; exit 1
fi
echo "✅ CI runs deployctl 2.4.1 and shadows.txt lists exactly what hid it"
