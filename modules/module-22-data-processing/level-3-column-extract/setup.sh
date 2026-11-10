#!/bin/bash
# Two newsletter exports from the same vendor with different column layouts:
#   old: id,name,email,country,signup_date                      (email = 3)
#   new: customer_id,email_verified,first_name,last_name,email,plan,created_at (email = 5)
# email_verified comes first in the new one, so a loose "grep email" finds it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function addr(f, l,   r) {
  r = rand()
  if (r < 0.4) return tolower(f) "." tolower(l) "@" dom[int(rand() * nd) + 1]
  if (r < 0.7) return tolower(substr(f, 1, 1)) tolower(l) int(rand() * 99) "@" dom[int(rand() * nd) + 1]
  return tolower(f) "_" int(1960 + rand() * 45) "@" dom[int(rand() * nd) + 1]
}
BEGIN {
  srand(seed)
  nf = split("Adaeze Bjorn Camila Dario Esra Felix Giulia Hana Ivo Jonas Kaito Leila Marek Nora Olu Paula Rui Sanne Tariq Vera Wojtek Ximena Yusuf Zara", first, " ")
  nl = split("Andersen Bianchi Chen Diallo Engel Ferreira Gruber Haddad Ito Jovanovic Kaur Lindqvist Mensah Nowak Ortiz Park Quinn Ruiz Sato Toth Uddin Vogel Wolf", last, " ")
  nd = split("example.com mail.example.org post.example.net example.co.uk", dom, " ")
  nc = split("DE FR NL PL SE ES IT PT IE AT", ctry, " ")
  np = split("free basic pro team", plan, " ")
  print "id,name,email,country,signup_date" > "old_export.csv"
  n = 120 + int(rand() * 60)
  for (i = 1; i <= n; i++) {
    f = first[int(rand() * nf) + 1]; l = last[int(rand() * nl) + 1]
    printf "%d,%s %s,%s,%s,2025-%02d-%02d\n", 5000 + i * 3 + int(rand() * 3), f, l, addr(f, l), ctry[int(rand() * nc) + 1], 1 + int(rand() * 12), 1 + int(rand() * 28) > "old_export.csv"
  }
  print "customer_id,email_verified,first_name,last_name,email,plan,created_at" > "new_export.csv"
  n = 150 + int(rand() * 80)
  for (i = 1; i <= n; i++) {
    f = first[int(rand() * nf) + 1]; l = last[int(rand() * nl) + 1]
    printf "C%06d,%s,%s,%s,%s,%s,2026-%02d-%02dT%02d:%02d:00Z\n", int(rand() * 999999), (rand() < 0.7) ? "true" : "false", f, l, addr(f, l), plan[int(rand() * np) + 1], 1 + int(rand() * 10), 1 + int(rand() * 28), int(rand() * 24), int(rand() * 60) > "new_export.csv"
  }
}'

cat old_export.csv new_export.csv | cksum > .lm-state/exports.sum
