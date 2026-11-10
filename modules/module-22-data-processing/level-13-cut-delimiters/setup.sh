#!/bin/bash
# Bank Payroll File: a fixed-width payroll transfer file (header record H,
# detail records D, trailer record T) plus the bank's LAYOUT.txt. Names are
# padded to 30 columns, one is truncated by the bank at exactly 30, a few are
# written "Last, First" (a comma inside the field), and amounts are 9 digits
# with implied decimals, some of them below 1.00. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > LAYOUT.txt <<'EOF'
NORDBANK PAYROLL TRANSFER FILE  -  record layout v3.2
Fixed width, one record per line, columns counted from 1.

Header record
  col  1        record type        'H'
  cols 2-9      creation date      YYYYMMDD
  cols 10-39    company name       left aligned, space padded

Detail record (one per payment)
  col  1        record type        'D'
  cols 2-7      employee id        6 digits, zero padded
  cols 8-37     beneficiary name   30 characters, left aligned, space padded
                                   (longer names are cut at 30 characters)
  cols 38-45    value date         YYYYMMDD
  cols 46-54    amount             9 digits, zero padded, 2 implied decimals
                                   (000012345 means 123.45)
  cols 55-57    currency           ISO 4217 code
  cols 58-79    IBAN               22 characters

Trailer record
  col  1        record type        'T'
  cols 2-7      number of detail records
  cols 8-20     sum of all amounts, 13 digits, 2 implied decimals
EOF

awk -v seed="$RANDOM$$" '
function pick(arr, n) { return arr[int(rand() * n) + 1] }
BEGIN {
  srand(seed)
  nf = split("Anna Lukas Mia Jonas Lea Elias Sofia Noah Emma Felix Hannah Paul Clara Ben Lina Jakob Marie David Ida Samuel Nora Oskar Greta Emil Tilda Anton Frida Moritz Ella Henrik", first, " ")
  nl = split("Berg Okafor Lindqvist Novak Haas Moreau Rossi Jensen Kowalski Brandt Dubois Silva Petersen Krause Nilsson Fischer Varga Horvat Andersen Weber Lund Costa Meyer Holm Sorensen Engel Falk Vogel Strand Kaya", last, " ")
  n = 150 + int(rand() * 40)
  date = sprintf("202611%02d", 25 + int(rand() * 4))
  printf "H%s%-30s\n", "20261120", "LINDHOLM LOGISTICS AB"
  # which records get the special names
  comma[int(rand() * 40) + 5] = 1; comma[int(rand() * 40) + 60] = 1; comma[int(rand() * 40) + 110] = 1
  longn = int(rand() * 30) + 45
  small = int(rand() * 40) + 80
  total = 0
  for (i = 1; i <= n; i++) {
    do id = 1000 + int(rand() * 98000); while (id in used)
    used[id] = 1
    f = pick(first, nf); l = pick(last, nl)
    if (i in comma) name = l ", " f
    else if (i == longn) name = "Maximiliane Featherstonehaugh-Lindqvist"
    else if (rand() < 0.08) name = f " " pick(first, nf) " " l
    else name = f " " l
    name = substr(name, 1, 30)
    r = rand()
    if (r < 0.04 || i == small) cents = 1 + int(rand() * 99)              # rounding adjustments below 1.00
    else if (r < 0.10) cents = 1000 + int(rand() * 40000)    # expense refunds
    else cents = 210000 + int(rand() * 540000)               # salaries
    total += cents
    iban = sprintf("SE%02d%04d%014d", int(rand() * 90) + 10, 5000 + int(rand() * 999), int(rand() * 1e14))
    printf "D%06d%-30s%s%09d%s%s\n", id, name, date, cents, "SEK", iban
  }
  printf "T%06d%013d\n", n, total
}' > payroll.dat

cksum < payroll.dat > .lm-state/payroll.sum
