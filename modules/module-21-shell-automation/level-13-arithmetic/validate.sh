#!/bin/bash
# Runs quota_report.sh on the shipped usage.tsv and on a freshly generated
# dataset (random zero-padded sizes, an exact 90 % user, an over-quota user,
# an unlimited user, numbers that are valid octal) and compares the output
# with what awk computes in decimal.
SANDBOX="$1"
SCRIPT="$SANDBOX/quota_report.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ quota_report.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# expected FILE: the right report, computed with integer maths in awk
expected() {
  awk -F'\t' 'NR > 1 {
      used = $2 + 0; quota = $3 + 0; total += used
      if (quota > 0) {
        p = (used * 100 - (used * 100) % quota) / quota
        if (p >= 90) printf "%s %d%%\n", $1, p
      }
    }
    END { printf "TOTAL %d MiB\n", (total - total % 1024) / 1024 }' "$1"
}

# check FILE LABEL
check() {
  (cd "$WORK" && $LIMIT bash "$SCRIPT" "$1" </dev/null >"$WORK/out" 2>"$WORK/err")
  code=$?
  want="$(expected "$1")"
  got="$(tr -d '\r' < "$WORK/out")"
  if [ "$code" != 0 ]; then
    echo "❌ on $2, quota_report.sh exited with status $code: $(head -1 "$WORK/err")"
    exit 1
  fi
  if [ "$got" != "$want" ]; then
    if [ -s "$WORK/err" ]; then
      echo "❌ on $2 the report is wrong, and bash said: $(head -1 "$WORK/err")"
    elif [ "$(printf '%s\n' "$got" | tail -1)" != "$(printf '%s\n' "$want" | tail -1)" ] &&
         [ "$(printf '%s\n' "$got" | sed '$d')" = "$(printf '%s\n' "$want" | sed '$d')" ]; then
      echo "❌ on $2 the user lines are right but the TOTAL line is not (add everything up first, divide once)"
    else
      n="$(printf '%s\n' "$want" | grep -vc '^TOTAL')"
      echo "❌ on $2 the report is wrong: expected $n user line(s) and a TOTAL line, got: $(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)"
    fi
    exit 1
  fi
  if [ -s "$WORK/err" ]; then
    echo "❌ on $2 the report is right, but bash also printed errors: $(head -1 "$WORK/err")"
    exit 1
  fi
}

check "$SANDBOX/usage.tsv" "usage.tsv"

# A second, unseen export.
data="$WORK/usage-week46.tsv"
printf 'user\tused_kib\tquota_kib\n' > "$data"
row() { printf '%s\t%08d\t%08d\n' "$1" "$2" "$3" >> "$data"; }
q=$(( (RANDOM % 50 + 20) * 10240 ))
row "olga" $(( q * 9 / 10 )) "$q"                       # exactly 90 %
row "pavel" $(( q * 9 / 10 - 1 )) "$q"                  # just under
row "quinn" $(( 7777777 - RANDOM )) "$(( 4194304 ))"    # over quota
row "rosa" $(( RANDOM * 3 + 9 )) 0                      # unlimited
row "sven" 7654321 7777777                              # valid octal: 98 %
row "tara" 0 "$q"
for u in uma victor wanda xiao yusuf zoe; do
  qq=$(( (RANDOM % 900 + 100) * 1024 ))
  row "$u" $(( qq * (RANDOM % 25 + 78) / 100 + RANDOM % 1000 )) "$qq"
done
check "$data" "a second usage export"

echo "✅ quota_report.sh reads zero-padded sizes as decimal and gets every percent and the total right"
exit 0
