#!/bin/bash
# Sources env.sh in a fresh shell from / (no SANDBOX variable, minimal PATH)
# and checks where each command resolves.
SANDBOX="$1"
ENVSH="$SANDBOX/env.sh"

if [ ! -f "$ENVSH" ]; then
  echo "❌ env.sh is missing (type reset to get it back)"
  exit 1
fi
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

out="$(cd / && $LIMIT env -i HOME=/nonexistent PATH=/usr/bin:/bin bash --noprofile --norc -c '
  source "$1" >/dev/null 2>&1
  printf "PATH=%s\n" "$PATH"
  printf "TARGET=%s\n" "$(printenv DEPLOY_TARGET)"
  for c in deploy-helper report-legacy ls grep sort; do printf "%s=%s\n" "$c" "$(command -v "$c")"; done
' _ "$ENVSH" </dev/null 2>/dev/null)"

get() { printf '%s\n' "$out" | sed -n "s/^$1=//p" | head -1; }
real() { (cd "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")"); }

path="$(get PATH)"
TOOLS="$(cd "$SANDBOX/tools/bin" && pwd -P)"
LEGACY="$(cd "$SANDBOX/legacy/bin" && pwd -P)"

# PATH entries must all be absolute directories.
case ":$path:" in
  *::*) echo "❌ after source env.sh, PATH has an empty entry (a leading, trailing or double colon), which means the current directory"; exit 1 ;;
esac
old_ifs="$IFS"; IFS=:
for entry in $path; do
  case "$entry" in
    .) IFS="$old_ifs"; echo "❌ after source env.sh, PATH contains '.', so commands depend on the directory you are in"; exit 1 ;;
    /*) ;;
    *) IFS="$old_ifs"; echo "❌ after source env.sh, PATH contains the relative entry '$entry'; it only works from inside the sandbox"; exit 1 ;;
  esac
  if [ "$entry" = /tools/bin ] || [ "$entry" = /legacy/bin ]; then
    IFS="$old_ifs"
    echo "❌ after source env.sh, PATH contains '$entry': a variable in env.sh (like \$SANDBOX) is empty in other shells; write the real path"
    exit 1
  fi
done
IFS="$old_ifs"

for c in ls grep sort; do
  if [ -z "$(get "$c")" ]; then
    echo "❌ after source env.sh, '$c' is not found any more: the system directories are gone from PATH"
    exit 1
  fi
done

dh="$(get deploy-helper)"
if [ -z "$dh" ]; then
  echo "❌ after source env.sh, deploy-helper is not found at all"
  exit 1
fi
case "$(real "$dh")" in
  "$TOOLS/deploy-helper") ;;
  "$LEGACY/deploy-helper") echo "❌ deploy-helper still resolves to legacy/bin: PATH is searched left to right and the first match wins"; exit 1 ;;
  *) echo "❌ deploy-helper resolves to $dh, expected the copy in tools/bin"; exit 1 ;;
esac

if [ "$(real "$(get report-legacy)")" != "$LEGACY/report-legacy" ]; then
  echo "❌ report-legacy is no longer found after source env.sh; legacy/bin must stay on PATH"
  exit 1
fi
if [ "$(get TARGET)" != staging ]; then
  echo "❌ env.sh no longer exports DEPLOY_TARGET=staging; keep its other settings"
  exit 1
fi

echo "✅ env.sh now finds deploy-helper in tools/bin, keeps report-legacy and the system commands"
exit 0
