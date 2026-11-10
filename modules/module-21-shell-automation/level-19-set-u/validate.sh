#!/bin/bash
# Checks that clean_build.sh turns on nounset, then runs it in scratch copies
# of a workspace with canary files: PROJECT unset and empty (must fail and
# delete nothing), PROJECT set with no TARGET and no DEBUG (only build/ is
# emptied), a TARGET (only build/TARGET goes), and DEBUG=1.
SANDBOX="$1"
SCRIPT="$SANDBOX/clean_build.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ clean_build.sh is missing (type reset to get it back)"
  exit 1
fi

setlines="$(sed 's/#.*//' "$SCRIPT" | grep -E '^[[:space:]]*set[[:space:]]')"
if ! printf '%s\n' "$setlines" | grep -Eq -- '[[:space:]]-[a-zA-Z]*u|-o[[:space:]]+nounset'; then
  echo "❌ clean_build.sh does not turn on 'set -u' yet (an unset variable should stop the script)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# fresh: a scratch copy with three projects in $R
fresh() {
  R="$WORK/r$RANDOM"
  mkdir -p "$R"
  cp "$SCRIPT" "$R/clean_build.sh"
  for p in web payments infra; do
    mkdir -p "$R/workspace/$p/src/lib" "$R/workspace/$p/build/tests" "$R/workspace/$p/build/pkg"
    echo "canary $p" > "$R/workspace/$p/src/main.go"
    echo "canary $p lib" > "$R/workspace/$p/src/lib/db.go"
    echo "canary $p readme" > "$R/workspace/$p/README.md"
    echo "bin" > "$R/workspace/$p/build/$p"
    echo "xml" > "$R/workspace/$p/build/tests/junit.xml"
    echo "deb" > "$R/workspace/$p/build/pkg/$p.deb"
  done
  echo "keep me" > "$R/workspace/NOTES.md"
}
tree() { (cd "$R/workspace" && find . | LC_ALL=C sort); }
# run [VAR=value...] -- ARGS
run() {
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  (cd "$R" && $LIMIT env -u PROJECT -u DEBUG ${envs[@]+"${envs[@]}"} bash ./clean_build.sh "$@" </dev/null >"$R/.out" 2>"$R/.err")
  CODE=$?
}

# 1. PROJECT unset / empty: fail, delete nothing
for how in unset empty; do
  fresh
  before="$(tree)"
  if [ "$how" = unset ]; then run -- ; else run PROJECT= -- ; fi
  if [ "$(tree)" != "$before" ]; then
    echo "❌ with PROJECT $how, clean_build.sh deleted files in workspace/; it must stop before rm"
    exit 1
  fi
  if [ "$CODE" = 0 ]; then
    echo "❌ with PROJECT $how, clean_build.sh deletes nothing but still exits 0; it must fail"
    exit 1
  fi
done

# 2. PROJECT=web, no TARGET, no DEBUG: build/ empty, nothing else touched
fresh
want="$(tree | grep -v '^\./web/build/')"
run PROJECT=web --
if [ "$CODE" != 0 ]; then
  echo "❌ PROJECT=web ./clean_build.sh (no TARGET, no DEBUG) failed with status $CODE: $(head -1 "$R/.err")"
  exit 1
fi
got="$(tree)"
if [ "$got" != "$want" ]; then
  if ! printf '%s\n' "$got" | grep -qx './web/src/main.go'; then
    echo "❌ PROJECT=web ./clean_build.sh deleted more than build/ (src/ is gone)"
  elif ! printf '%s\n' "$got" | grep -qx './web/build'; then
    echo "❌ PROJECT=web ./clean_build.sh removed build/ itself; empty it, keep the folder"
  else
    echo "❌ PROJECT=web ./clean_build.sh did not empty workspace/web/build (or touched another project)"
  fi
  exit 1
fi

# 3. a TARGET: only build/tests goes
fresh
want="$(tree | grep -v '^\./payments/build/tests')"
run PROJECT=payments -- tests
if [ "$CODE" != 0 ] || [ "$(tree)" != "$want" ]; then
  echo "❌ PROJECT=payments ./clean_build.sh tests should remove only workspace/payments/build/tests (status $CODE)"
  exit 1
fi

# 4. DEBUG=1 still works and talks on stderr
fresh
want="$(tree | grep -v '^\./infra/build/')"
run PROJECT=infra DEBUG=1 --
if [ "$CODE" != 0 ] || [ "$(tree)" != "$want" ]; then
  echo "❌ PROJECT=infra DEBUG=1 ./clean_build.sh should empty infra/build like without DEBUG (status $CODE): $(head -1 "$R/.err")"
  exit 1
fi
if [ ! -s "$R/.err" ]; then
  echo "❌ with DEBUG=1, clean_build.sh should print what it removes on stderr"
  exit 1
fi

echo "✅ clean_build.sh stops on unset variables, and with valid input empties only build/"
exit 0
