#!/bin/bash
# Sources lib/units.sh in a fresh bash for each input, calls to_bytes directly
# (not in a subshell), and checks: stdout, return status, that the shell is
# still alive, and that no variable of the caller was created or changed
# (declare -p before and after). Then runs check_upload.sh end to end.
SANDBOX="$1"

if [ ! -f "$SANDBOX/lib/units.sh" ]; then
  echo "❌ lib/units.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/lib"
cp "$SANDBOX/lib/units.sh" "$WORK/lib/units.sh"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# bash 4+ prints `declare -- x="1"`, bash 3.2 prints `x=1`: strip the prefix first.
DYNAMIC='^(_|BASH_[A-Z_]*|FUNCNAME|PIPESTATUS|LINENO|RANDOM|SRANDOM|SECONDS|EPOCHREALTIME|EPOCHSECONDS|OPTIND|OPTARG|OPTERR|COLUMNS|LINES|HISTCMD)(=|$)'

# INPUT|expected stdout ('-' = must fail with status 1 and print nothing)
CASES=(
  "512|512" "300|300" "0|0" "12K|12288" "1023K|1047552" "3M|3145728"
  "2G|2147483648" "1T|1099511627776" "640M|671088640"
  "abc|-" "|-" "12KB|-" "1.5G|-" "-3|-" "K|-" "5 M|-" "M3|-"
)
for c in "${CASES[@]}"; do
  input=${c%|*}
  want=${c##*|}
  rm -f out status before.vars after.vars
  $LIMIT env -i PATH="$PATH" bash --noprofile --norc -c '
    source ./lib/units.sh >/dev/null 2>&1
    size="caller size"; unit="caller unit"; bytes=7; n=7; num=7; mult=7; result=7
    declare -p > before.vars
    to_bytes "$1" > out 2>/dev/null
    echo $? > status
    declare -p > after.vars
  ' _ "$input" </dev/null >/dev/null 2>&1
  if [ ! -f status ]; then
    echo "❌ to_bytes '$input' ended the caller's whole shell; a function must use return, not exit"
    exit 1
  fi
  st=$(cat status)
  got=$(cat out)
  if [ "$want" = - ]; then
    if [ "$st" != 1 ] || [ -n "$got" ]; then
      echo "❌ to_bytes '$input' is not a valid size: it must print nothing and return 1 (it printed '$got', returned $st)"
      exit 1
    fi
  elif [ "$got" != "$want" ] || [ "$st" != 0 ]; then
    echo "❌ to_bytes $input printed '$got' and returned $st; expected it to print $want and return 0"
    exit 1
  fi
  vars() { sed 's/^declare -[^ ]* //' "$1" | grep -Ev "$DYNAMIC"; }
  changed=$(diff <(vars before.vars) <(vars after.vars) \
            | sed -n 's/^[<>] \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | sort -u | tr '\n' ' ')
  if [ -n "$changed" ]; then
    echo "❌ calling to_bytes '$input' created or changed the caller's variable(s): $changed(make them local)"
    exit 1
  fi
done

# End to end: the existing caller must now work unchanged.
cp "$SANDBOX/check_upload.sh" ./check_upload.sh 2>/dev/null || exit 1
mkdir up
head -c 2048 /dev/zero > up/exact.bin
head -c 2049 /dev/zero > "up/one more.bin"
head -c 70000 /dev/zero > up/big.bin
$LIMIT bash ./check_upload.sh 2K up/exact.bin "up/one more.bin" up/big.bin </dev/null >out 2>err
want=$'too big: up/one more.bin (2049 bytes, limit 2048)\ntoo big: up/big.bin (70000 bytes, limit 2048)'
if [ "$(cat out)" != "$want" ]; then
  echo "❌ ./check_upload.sh 2K ... printed '$(head -n 1 out)' (stderr: '$(head -n 1 err)'); it should list the 2 files over 2048 bytes"
  exit 1
fi

echo "✅ to_bytes prints its result, returns 0 or 1 as a status, and leaves the caller's variables alone"
exit 0
