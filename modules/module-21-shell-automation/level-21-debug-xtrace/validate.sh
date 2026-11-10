#!/bin/bash
# Runs invoice_sync.sh on the shipped data and on a generated dataset whose
# customer names contain glob characters (* ? [ ]) next to names they would
# match as patterns. Compares the report with totals computed by awk using
# exact name matching. Then checks the debug mode: with DEBUG=1, trace.log
# gets xtrace lines prefixed with file:line, stdout is the same report and
# stderr holds no trace; without DEBUG, no trace.log appears.
SANDBOX="$1"
SCRIPT="$SANDBOX/invoice_sync.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ invoice_sync.sh is missing (type reset to get it back)"
  exit 1
fi
if [ ! -f "$SANDBOX/data/customers.txt" ] || [ ! -f "$SANDBOX/data/invoices.csv" ]; then
  echo "❌ data/customers.txt or data/invoices.csv is missing (type reset)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

# expected DIR: the report, with exact customer names
expected() {
  awk -F';' '
    function eur(c,   s) { s = ""; if (c < 0) { s = "-"; c = -c }
                           return sprintf("%s%d.%02d", s, int(c / 100), c % 100) }
    FILENAME ~ /customers/ { if ($0 != "") { order[++n] = $0 }; next }
    FNR == 1 { next }
    {
      sub(/\r$/, "", $4)
      if ($1 !~ /^INV-[0-9]+$/ || $3 !~ /^[0-9]+$/) next
      if ($4 != "paid" && $4 != "open" && $4 != "void" && $4 != "credit") next
      if ($1 in seen) next
      seen[$1] = 1
      if ($4 == "paid") tot[$2] += $3
      if ($4 == "credit") tot[$2] -= $3
    }
    END {
      for (i = 1; i <= n; i++) { printf "%s: %s\n", order[i], eur(tot[order[i]] + 0); g += tot[order[i]] }
      printf "TOTAL: %s\n", eur(g + 0)
    }' "$1/customers.txt" "$1/invoices.csv"
}

# run DIR [VAR=value...]: run a copy of the script in $R on data dir DIR
run() {
  local data="$1"; shift
  R="$WORK/run$RANDOM"
  mkdir -p "$R"
  cp "$SCRIPT" "$R/invoice_sync.sh"
  (cd "$R" && $LIMIT env -u DEBUG "$@" bash ./invoice_sync.sh "$data" </dev/null >"$R/.out" 2>"$R/.err")
  CODE=$?
}

# report_ok DIR LABEL
report_ok() {
  want="$(expected "$1")"
  if [ "$CODE" != 0 ]; then
    echo "❌ on $2, invoice_sync.sh exited with status $CODE: $(head -1 "$R/.err")"
    exit 1
  fi
  if [ "$(cat "$R/.out")" != "$want" ]; then
    bad="$(diff <(printf '%s\n' "$want") "$R/.out" | grep '^>' | head -1 | cut -c3-)"
    echo "❌ on $2, a total is wrong: '$bad'"
    exit 1
  fi
}

# 1. shipped data, no DEBUG
run "$SANDBOX/data"
report_ok "$SANDBOX/data" "the shipped data"
if [ -e "$R/trace.log" ]; then
  echo "❌ without DEBUG, invoice_sync.sh still creates trace.log"
  exit 1
fi

# 2. generated data with glob characters in names
D="$WORK/data2"
mkdir -p "$D"
printf '%s\n' "Q*Bert Games" "Quality Bert Games" "Who? Inc" "Whom Inc" "[Beta] Labs" "a Labs" "E*Trade Europe" "Plain Co" > "$D/customers.txt"
echo "invoice_id;customer;amount_cents;status" > "$D/invoices.csv"
id=5000
while IFS= read -r c; do
  for k in 1 2 3; do
    id=$(( id + 1 + RANDOM % 3 ))
    case $(( RANDOM % 5 )) in
      0) st=credit; amt=$(( RANDOM % 900 + 100 )) ;;
      1) st=open;   amt=$(( RANDOM * 3 )) ;;
      *) st=paid;   amt=$(( RANDOM * 2 + 5000 )) ;;
    esac
    echo "INV-$id;$c;$amt;$st" >> "$D/invoices.csv"
  done
done < "$D/customers.txt"
run "$D"
report_ok "$D" "a second dataset with *, ? and [ ] in customer names"

# 3. DEBUG=1: trace in trace.log with file:line, clean stdout and stderr
run "$SANDBOX/data" DEBUG=1
if [ "$CODE" != 0 ]; then
  echo "❌ with DEBUG=1, invoice_sync.sh exited with status $CODE: $(head -1 "$R/.err")"
  exit 1
fi
if [ ! -s "$R/trace.log" ]; then
  echo "❌ with DEBUG=1, run in some directory, invoice_sync.sh should write its trace to trace.log in that directory"
  exit 1
fi
if [ "$(cat "$R/.out")" != "$(expected "$SANDBOX/data")" ]; then
  echo "❌ with DEBUG=1, stdout is not the plain report any more; the trace must go only to trace.log"
  exit 1
fi
if grep -q '^+' "$R/.err"; then
  echo "❌ with DEBUG=1, trace lines still appear on stderr; send them to trace.log only (BASH_XTRACEFD)"
  exit 1
fi
total_lines="$(grep -c . "$R/trace.log")"
prefixed="$(grep -cE '^\++ ?[^ ]*invoice_sync\.sh:[0-9]+: ?' "$R/trace.log")"
if [ "$total_lines" -lt 30 ]; then
  echo "❌ trace.log has only $total_lines lines; turn on xtrace (set -x) for the whole run"
  exit 1
fi
if [ $(( prefixed * 10 )) -lt $(( total_lines * 9 )) ]; then
  echo "❌ trace.log lines should start like '+invoice_sync.sh:42: ' (file and line number in PS4); first line: $(head -1 "$R/trace.log")"
  exit 1
fi
distinct="$(grep -oE 'invoice_sync\.sh:[0-9]+:' "$R/trace.log" | sort -u | wc -l | tr -d ' ')"
if [ "$distinct" -lt 10 ]; then
  echo "❌ the line numbers in trace.log hardly change ($distinct different ones); PS4 must be expanded at every trace line (single quotes)"
  exit 1
fi

echo "✅ invoice_sync.sh matches customer names exactly, and DEBUG=1 writes a file:line trace to trace.log"
exit 0
