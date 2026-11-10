#!/bin/bash
# Sets mtimes with `touch -t` in a scratch dir and runs needs_rebuild.sh in
# about 15 cases: newer/older/equal sources, a missing target, a dangling
# symlink as target and as source, a symlinked target and source, names with
# spaces, a missing and an unreadable source, too few arguments. Checks the
# exit status, the stderr message for errors, and that stdout stays empty.
SANDBOX="$1"
SCRIPT="$SANDBOX/needs_rebuild.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ needs_rebuild.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/needs_rebuild.sh"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

stamp() { echo "$2" > "$1"; touch -t "$3" "$1"; }
stamp lib.o      target   202611101000.00
stamp a.c        a        202611100900.00
stamp b.h        b        202611100930.00
stamp new.c      new      202611101100.00
stamp same.c     same     202611101000.00
stamp "my file.c" spaced  202611100930.00
stamp secret.c   secret   202611100900.00
chmod 000 secret.c
ln -s lib.o current.o
ln -s does-not-exist.o dead.o
ln -s new.c link-new.c
ln -s gone.c dangling.c

# expected-exit | stderr must contain ('' = anything) | args...
check() {
  want=$1 msg=$2; shift 2
  $LIMIT bash ./needs_rebuild.sh "$@" </dev/null >out 2>err
  code=$?
  shown=$(printf "'%s' " "$@")
  if [ "$code" != "$want" ]; then
    case $want in
      0) meaning="must be rebuilt" ;;
      1) meaning="is up to date" ;;
      2) meaning="is an error" ;;
    esac
    echo "❌ ./needs_rebuild.sh ${shown% } exited with $code, but this case $meaning (exit $want)"
    exit 1
  fi
  if [ -s out ]; then
    echo "❌ ./needs_rebuild.sh ${shown% } printed on stdout ('$(head -n 1 out)'); only the exit status may answer"
    exit 1
  fi
  if [ -n "$msg" ] && ! grep -qF -- "$msg" err; then
    echo "❌ ./needs_rebuild.sh ${shown% } must say '$msg' on stderr (it said: '$(head -n 1 err)')"
    exit 1
  fi
}

check 1 "" lib.o a.c b.h
check 0 "" lib.o a.c new.c
check 1 "" lib.o same.c
check 1 "" lib.o a.c b.h same.c "my file.c"
check 0 "" "my file.c" new.c
check 1 "" "my file.c" a.c
check 0 "" missing.o a.c
check 0 "" dead.o a.c b.h
check 1 "" current.o a.c
check 0 "" current.o new.c
check 0 "" lib.o link-new.c
check 2 "missing source: nothere.c" lib.o a.c nothere.c
check 2 "missing source: nothere.c" missing.o nothere.c
check 2 "broken symlink: dangling.c" lib.o dangling.c
check 2 "" lib.o
check 2 ""
if [ ! -r secret.c ]; then   # (root can read anything; skip the case then)
  check 2 "unreadable source: secret.c" lib.o a.c secret.c
fi

echo "✅ needs_rebuild.sh decides exactly like make: missing, newer, equal, symlinks and errors"
exit 0
