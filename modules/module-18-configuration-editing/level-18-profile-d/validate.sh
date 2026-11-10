#!/bin/bash
# Source every etc/profile.d/*.sh the way /etc/profile does, in sh (dash) and in bash, with
# several starting PATHs. Check PATH, stderr, other scripts' variables and the missing-dir case.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
DIR="$SANDBOX/opt/tool/bin"
export SANDBOX

if ! ls etc/profile.d/*.sh 2>/dev/null | grep -q '/tool\.sh$'; then
  echo "❌ there is no etc/profile.d/tool.sh: login shells only source files ending in .sh"
  exit 1
fi

# usage: run_profile SHELL START_PATH TIMES -> prints "PATH=..." and "EDITOR=..."; stderr to $ERR
ERR=$(mktemp); trap 'rm -f "$ERR"' EXIT
run_profile() {
  local shell=$1 start=$2 times=$3
  env -i HOME="$SANDBOX" SANDBOX="$SANDBOX" PATH="$start" "$shell" -c '
    n=$1
    while [ "$n" -gt 0 ]; do
      for i in "$SANDBOX"/etc/profile.d/*.sh; do
        if [ -r "$i" ]; then . "$i"; fi
      done
      n=$((n - 1))
    done
    echo "PATH=$PATH"; echo "EDITOR=$EDITOR"
  ' sh "$times" 2>"$ERR"
}
count() { printf '%s\n' "$1" | tr ':' '\n' | grep -cxF "$2"; }

BASE=/usr/local/bin:/usr/bin:/bin
for shell in sh bash; do
  for case_ in "twice:$BASE:2" "present:$BASE:$DIR:1" "lookalike:$BASE:${DIR}2:2"; do
    name=${case_%%:*}; rest=${case_#*:}; times=${rest##*:}; start=${rest%:*}
    out=$(run_profile "$shell" "$start" "$times")
    if [ -s "$ERR" ]; then
      echo "❌ sourcing the profile.d scripts under $shell prints errors: $(head -1 "$ERR")"
      exit 1
    fi
    path=$(printf '%s\n' "$out" | sed -n 's/^PATH=//p')
    n=$(count "$path" "$DIR")
    if [ "$n" != 1 ]; then
      case $name in
        twice)     echo "❌ under $shell, after sourcing twice PATH contains the tool directory $n times, expected exactly once" ;;
        present)   echo "❌ under $shell, with the directory already in PATH it ends up $n times, expected exactly once" ;;
        lookalike) echo "❌ under $shell, a different directory whose name only starts the same ($DIR""2) fooled the check: tool dir found $n times" ;;
      esac
      exit 1
    fi
    if [ "$(printf '%s\n' "$out" | sed -n 's/^EDITOR=//p')" != vi ]; then
      echo "❌ under $shell the other profile.d scripts no longer work (EDITOR is not set)"
      exit 1
    fi
  done
done

# Missing directory: PATH must be exactly what it was.
mv opt/tool/bin opt/tool/bin.away
trap 'mv opt/tool/bin.away opt/tool/bin 2>/dev/null; rm -f "$ERR"' EXIT
for shell in sh bash; do
  out=$(run_profile "$shell" "$BASE" 2)
  path=$(printf '%s\n' "$out" | sed -n 's/^PATH=//p')
  if [ "$path" != "$BASE" ]; then
    echo "❌ under $shell, with the directory missing PATH changed to '$path'; it must stay untouched"
    exit 1
  fi
done
echo "✅ tool.sh puts opt/tool/bin in PATH exactly once under sh and bash, and only when it exists"
exit 0
