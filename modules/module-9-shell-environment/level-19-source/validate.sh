#!/bin/bash
# Sources the player's workon.sh in clean shells started from other directories,
# with good and bad project names, and also runs it as a program.
SANDBOX="$1"
S="$(cd "$SANDBOX" && pwd -P)"
cd "$S" || exit 1

if [ ! -f workon.sh ]; then
  echo "❌ workon.sh is missing (type reset)"
  exit 1
fi
for p in api web; do
  if [ ! -f "projects/$p/.project.env" ]; then
    echo "❌ projects/$p/.project.env is missing (type reset)"
    exit 1
  fi
done

WORK="$(mktemp -d "$S/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/elsewhere"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# run_in DIR SCRIPT: clean bash in DIR runs SCRIPT; stdout -> out, stderr -> err
run_in() {
  (cd "$1" && $LIMIT env -i PATH=/usr/bin:/bin HOME="$WORK" bash --noprofile --norc -c "$2" \
     </dev/null >"$WORK/out" 2>"$WORK/err")
}
val() { grep "^$1=" "$WORK/out" | head -1 | cut -d= -f2-; }

# check_project NAME HOW: compare the probe output with projects/NAME/.project.env
check_project() {
  local name="$1" how="$2" k want
  if ! grep -q '^ALIVE' "$WORK/out"; then
    echo "❌ $how: the shell closed"
    exit 1
  fi
  if [ "$(val PWD)" != "$S/projects/$name" ]; then
    echo "❌ $how: the shell ends up in $(val PWD), not in projects/$name"
    exit 1
  fi
  if [ "$(val ENV_PROJECT)" != "$name" ]; then
    echo "❌ $how: PROJECT is not exported as '$name' (child processes see '$(val ENV_PROJECT)')"
    exit 1
  fi
  for k in PROJECT_PORT PROJECT_DB PROJECT_LOG; do
    want="$(grep "^$k=" "projects/$name/.project.env" | cut -d= -f2-)"
    if [ "$(val "ENV_$k")" != "$want" ]; then
      echo "❌ $how: $k from projects/$name/.project.env is not exported"
      exit 1
    fi
  done
}
PROBE='echo ALIVE; echo "PWD=$(pwd -P)"; for k in PROJECT PROJECT_PORT PROJECT_DB PROJECT_LOG; do echo "ENV_$k=$(printenv "$k")"; done'

# 1. Sourced by absolute path from an unrelated directory.
run_in "$WORK/elsewhere" "source '$S/workon.sh' api; $PROBE"
grep -q "no such project" "$WORK/err" && { echo "❌ from another directory, source $S/workon.sh api still says 'no such project': the script looks for projects/ in the wrong place"; exit 1; }
check_project api "source workon.sh api from another directory"

# 2. Sourced by a relative path from inside projects/.
run_in "$S/projects" "source ../workon.sh web; $PROBE"
grep -q "no such project" "$WORK/err" && { echo "❌ from projects/, source ../workon.sh web says 'no such project'"; exit 1; }
check_project web "source ../workon.sh web from projects/"

# 3. A bad name must not kill the caller, must fail, and must change nothing.
run_in "$WORK/elsewhere" "source '$S/workon.sh' apo; echo \"ALIVE status=\$?\"; echo \"PWD=\$(pwd -P)\"; echo \"ENV_PROJECT=\$(printenv PROJECT)\""
if ! grep -q '^ALIVE' "$WORK/out"; then
  echo "❌ source workon.sh apo (unknown project) still closes the shell that sourced it"
  exit 1
fi
if grep -q '^ALIVE status=0$' "$WORK/out"; then
  echo "❌ source workon.sh apo returns status 0; an unknown project must give a non-zero status"
  exit 1
fi
if [ "$(val PWD)" != "$WORK/elsewhere" ] || [ -n "$(val ENV_PROJECT)" ]; then
  echo "❌ source workon.sh apo changed the directory or set PROJECT; a failed call must change nothing"
  exit 1
fi
if [ ! -s "$WORK/err" ]; then
  echo "❌ source workon.sh apo should still print an error message (on stderr)"
  exit 1
fi

# 4. Executed instead of sourced: refuse, and say how to use it.
(cd "$WORK/elsewhere" && $LIMIT env -i PATH=/usr/bin:/bin HOME="$WORK" bash "$S/workon.sh" api \
   </dev/null >"$WORK/out" 2>&1)
code=$?
if [ "$code" -eq 0 ] || ! grep -q 'source' "$WORK/out"; then
  echo "❌ run as a program (bash workon.sh api) it should exit non-zero with a message that it must be sourced (mention 'source')"
  exit 1
fi

echo "✅ workon.sh works from any directory, survives bad names, and refuses to run unsourced"
exit 0
