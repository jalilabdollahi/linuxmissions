#!/bin/bash
# License Reconciliation: seats bought (licenses.txt: mixed case, trailing
# spaces, a comment and blank lines, a seat listed twice), the directory
# export (directory.csv with an enabled column) and 30 days of SSO events
# (active_30d.log: repeated users, failed logins, the user= key not always in
# the same field, logins by accounts disabled since). Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function mixcase(u,   r) { r = rand(); if (r < 0.55) return u; if (r < 0.8) return toupper(substr(u, 1, 1)) substr(u, 2); if (r < 0.9) return toupper(substr(u, 1, 2)) substr(u, 3); return toupper(u) }
function ev(u, ok,   d, extra) {
  d = int(rand() * 30)
  extra = (rand() < 0.35) ? " mfa=" (rand() < 0.5 ? "push" : "totp") : ""
  printf "2026-%s %02d:%02d:%02dZ sso event=login result=%s%s user=%s app=figma ip=10.%d.%d.%d\n", day[d], 7 + int(rand() * 11), int(rand() * 60), int(rand() * 60), ok ? "success" : "failure", extra, mixcase(u), 4 + int(rand() * 3), int(rand() * 255), 2 + int(rand() * 250) > "events.tmp"
}
BEGIN {
  srand(seed)
  for (d = 0; d < 30; d++) { m = (d < 20) ? 10 : 11; dd = (d < 20) ? 12 + d : d - 19; day[d] = sprintf("%02d-%02d", m, dd) }
  nf = split("anna ben chen dana elif femi greta hugo ines jonas kofi lara mats nina omar petra quinn rosa sven tara uwe vera wim yara", fn, " ")
  nl = split("berg okafor wei kovac yilmaz adeyemi lind marchetti duarte weber mensah novak holm strand falk vogel engel kaya costa lund", ln, " ")
  split("Design Product Marketing Engineering Sales Support", dept, " ")
  n = 110 + int(rand() * 30)
  print "username,display_name,department,enabled" > "directory.csv"
  for (i = 1; i <= n; i++) {
    do { a = fn[int(rand() * nf) + 1]; b = ln[int(rand() * nl) + 1]; u = substr(a, 1, 1) b } while (u in seen)
    seen[u] = 1; user[i] = u
    en[i] = (rand() < 0.88) ? "yes" : "no"
    printf "%s,%s %s,%s,%s\n", u, toupper(substr(a, 1, 1)) substr(a, 2), toupper(substr(b, 1, 1)) substr(b, 2), dept[int(rand() * 6) + 1], en[i] > "directory.csv"
  }
  # the roles each account plays: licensed? logs in?
  print "# Figma Professional seats - renewal 2026-03-01 - owner: it-procurement" > "licenses.txt"
  print "" > "licenses.txt"
  for (i = 1; i <= n; i++) {
    lic = (rand() < 0.45)
    r = rand()
    if (en[i] == "no") login = (rand() < 0.6)          # logged in before being disabled
    else if (lic) login = (r < 0.75)
    else login = (r < 0.1)
    if (lic) {
      pad = (rand() < 0.3) ? substr("   ", 1, 1 + int(rand() * 3)) : ""
      print mixcase(user[i]) pad > "licenses.txt"
      if (rand() < 0.03) print mixcase(user[i]) > "licenses.txt"
    }
    if (login) { k = 1 + int(rand() * 9); for (j = 0; j < k; j++) ev(user[i], rand() < 0.9); ev(user[i], 1) }
    else if (rand() < 0.15) ev(user[i], 0)            # only failed attempts
  }
  # two contractors who are gone from the directory still hold seats
  print "Tkarlsson " > "licenses.txt"; print "mpeyton" > "licenses.txt"
  ev("mpeyton", 0)
  print "" > "licenses.txt"
}'
sort -o active_30d.log events.tmp && rm events.tmp

cat licenses.txt directory.csv active_30d.log | cksum > .lm-state/inputs.sum
