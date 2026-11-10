#!/bin/bash
# logical.txt must be the path through the symlink, physical.txt the directory
# that deploy/current finally resolves to (two hops away).
SANDBOX="$1"
CUR="$SANDBOX/deploy/current"

if [ ! -L "$CUR" ] || [ ! -L "$SANDBOX/deploy/releases/live" ]; then
  echo "❌ the deploy/current or releases/live symlink was changed; type reset to restore them"
  exit 1
fi
REAL="$(cd "$CUR" && pwd -P)"
HOP1="$(cd "$SANDBOX/deploy/releases" && pwd -P)/live"

read_path() { tr -d '\r' < "$1" | sed -e 's/[[:space:]]*$//' -e '/^$/d'; }

for f in logical.txt physical.txt; do
  if [ ! -s "$SANDBOX/$f" ]; then
    stray="$(cd "$SANDBOX" && find . -mindepth 2 -name "$f" 2>/dev/null | head -1)"
    if [ -n "$stray" ]; then
      echo "❌ $f landed in ${stray#./}, not in the sandbox root (inside a symlinked dir, .. in a file path is the REAL parent)"
    else
      echo "❌ $f does not exist yet in the sandbox root (or is empty)"
    fi
    exit 1
  fi
  if [ "$(read_path "$SANDBOX/$f" | wc -l | tr -d ' ')" -ne 1 ]; then
    echo "❌ $f should hold exactly one path, on one line"
    exit 1
  fi
done

logical="$(read_path "$SANDBOX/logical.txt")"
physical="$(read_path "$SANDBOX/physical.txt")"

case "$logical" in
  /*) ;;
  *) echo "❌ logical.txt holds '$logical', which is not an absolute path"; exit 1 ;;
esac
# The sandbox itself may sit behind a symlink (macOS: /tmp -> /private/tmp);
# the shell may know it by either name, but the deploy/current part must stay.
CUR_P="$(cd "$SANDBOX" && pwd -P)/deploy/current"
if [ "$logical" != "$CUR" ] && [ "$logical" != "$CUR_P" ]; then
  if [ "$logical" = "$REAL" ]; then
    echo "❌ logical.txt holds the resolved release directory; it should be the path through the symlink (ending in deploy/current)"
  else
    echo "❌ logical.txt holds '$logical', expected the path of deploy/current as the shell shows it"
  fi
  exit 1
fi

case "$physical" in
  /*) ;;
  *) echo "❌ physical.txt holds '$physical', which is not an absolute path (readlink alone prints the link text, one hop)"; exit 1 ;;
esac
if [ "$physical" != "$REAL" ]; then
  if [ "$physical" = "$CUR" ] || [ "$physical" = "$CUR_P" ]; then
    echo "❌ physical.txt holds the symlink path; plain pwd shows the logical path, ask for the physical one"
  elif [ "$physical" = "$HOP1" ] || [ "${physical%/live}" != "$physical" ]; then
    echo "❌ physical.txt stops at releases/live, but live is a symlink too; resolve every hop"
  elif [ -d "$physical" ]; then
    echo "❌ physical.txt names a real directory, but not the one deploy/current points to right now"
  else
    echo "❌ physical.txt holds '$physical', which is not the directory behind deploy/current"
  fi
  exit 1
fi

echo "✅ deploy/current is really $(basename "$REAL"); both paths recorded"
exit 0
