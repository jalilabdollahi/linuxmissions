#!/bin/bash
# Trace the Total: invoice_sync.sh (about 120 lines) builds per-customer
# totals for accounting. One customer, "E*Trade Europe", is billed for another
# customer's invoices too: a helper compares names with an unquoted [[ == ]]
# right side, which is a glob pattern. Easy to see in an xtrace, hard to see
# by reading.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p data

cat > data/customers.txt <<'TXT'
Northwind Traders
E*Trade Europe
Eastside Trade Europe
Blue Harbor Ltd
Kestrel & Sons
TXT

cat > data/invoices.csv <<'TXT'
invoice_id;customer;amount_cents;status
INV-1001;Northwind Traders;125000;paid
INV-1002;E*Trade Europe;48050;paid
INV-1003;Eastside Trade Europe;310000;paid
INV-1004;Blue Harbor Ltd;9999;paid
INV-1005;Kestrel & Sons;45000;open
INV-1006;Northwind Traders;20000;credit
INV-1007;Eastside Trade Europe;15025;paid
INV-1008;E*Trade Europe;12000;void
INV-1009;Kestrel & Sons;87500;paid
INV-1010;Blue Harbor Ltd;30001;paid
INV-1011;Eastside Trade Europe;5000;credit
INV-1012;E*Trade Europe;99900;paid
INV-1013;Northwind Traders;7450;paid
INV-1014;Blue Harbor Ltd;abc;paid
INV-1015;Kestrel & Sons;12500;credit
INV-1007;Eastside Trade Europe;15025;paid
INV-1016;Northwind Traders;64000;open
TXT

cat > invoice_sync.sh <<'SCRIPT'
#!/bin/bash
# invoice_sync.sh [DATA_DIR]
#
# Builds the per-customer totals that are pushed to the accounting system.
# Reads DATA_DIR/customers.txt (one customer per line) and DATA_DIR/invoices.csv
# (invoice_id;customer;amount_cents;status). Prints "customer: total" for every
# customer, in the order of customers.txt, then "TOTAL: sum of those lines".
# Paid invoices are added, credit notes (status credit) are subtracted, open
# and void invoices are ignored. A row that appears twice counts once.
# Rows that cannot be parsed are reported on stderr and skipped.
# The same totals are written to outbox/totals.txt for the accounting push.

data_dir="${1:-data}"
customers_file="$data_dir/customers.txt"
invoices_file="$data_dir/invoices.csv"
outbox="outbox"

warn() {
  echo "invoice_sync: $*" >&2
}

die() {
  warn "$*"
  exit 1
}

check_inputs() {
  local header
  [ -r "$customers_file" ] || die "cannot read $customers_file"
  [ -r "$invoices_file" ] || die "cannot read $invoices_file"
  header=$(head -n 1 "$invoices_file")
  if [ "$header" != "invoice_id;customer;amount_cents;status" ]; then
    die "unexpected header in $invoices_file: $header"
  fi
}

# cents_to_eur 123456 -> 1234.56
cents_to_eur() {
  local cents=$1 sign=""
  if [ "$cents" -lt 0 ]; then
    sign="-"
    cents=$(( -cents ))
  fi
  printf '%s%d.%02d\n' "$sign" $(( cents / 100 )) $(( cents % 100 ))
}

# valid_row ID AMOUNT STATUS: is this row usable?
valid_row() {
  [[ $1 =~ ^INV-[0-9]+$ ]] || return 1
  [[ $2 =~ ^[0-9]+$ ]] || return 1
  case $3 in
    paid|open|void|credit) return 0 ;;
    *) return 1 ;;
  esac
}

# same_customer A B: true when both rows belong to one customer
same_customer() {
  [[ $1 == $2 ]]
}

# load_invoices: fills inv_customer, inv_amount and inv_status
inv_customer=()
inv_amount=()
inv_status=()
load_invoices() {
  local id customer amount status lineno=1 n=0
  local seen=" "
  while IFS=';' read -r id customer amount status; do
    lineno=$(( lineno + 1 ))
    status=${status%$'\r'}
    if ! valid_row "$id" "$amount" "$status"; then
      warn "line $lineno: cannot parse '$id;$customer;$amount;$status', skipped"
      continue
    fi
    case "$seen" in
      *" $id "*)
        warn "line $lineno: $id appears twice, counted once"
        continue
        ;;
    esac
    seen="$seen$id "
    inv_customer[n]="$customer"
    inv_amount[n]="$amount"
    inv_status[n]="$status"
    n=$(( n + 1 ))
  done < <(tail -n +2 "$invoices_file")
}

# sum_for_customer NAME: prints the total in cents
sum_for_customer() {
  local want="$1" total=0 i
  for (( i = 0; i < ${#inv_customer[@]}; i++ )); do
    same_customer "${inv_customer[i]}" "$want" || continue
    case "${inv_status[i]}" in
      paid)   total=$(( total + inv_amount[i] )) ;;
      credit) total=$(( total - inv_amount[i] )) ;;
    esac
  done
  echo "$total"
}

report() {
  local customer cents grand=0
  mkdir -p "$outbox"
  : > "$outbox/totals.txt"
  while IFS= read -r customer; do
    [ -n "$customer" ] || continue
    cents=$(sum_for_customer "$customer")
    grand=$(( grand + cents ))
    printf '%s: %s\n' "$customer" "$(cents_to_eur "$cents")"
    printf '%s\t%s\n' "$customer" "$cents" >> "$outbox/totals.txt"
  done < "$customers_file"
  printf 'TOTAL: %s\n' "$(cents_to_eur "$grand")"
}

check_inputs
load_invoices
report
SCRIPT
chmod +x invoice_sync.sh

cat > TICKET.txt <<'TXT'
ACC-2291  "E*Trade Europe disputes their October statement"
Their statement shows 4679.75. Their own books say 1479.50, and they are
right: we checked by hand. Every other customer's total is correct.
Nobody can see the bug by reading invoice_sync.sh.

Please also give the script a debug mode for next time: with DEBUG=1 it
should write a trace of every command, with file name and line number, to
trace.log, without mixing it into the report on stdout.
TXT
