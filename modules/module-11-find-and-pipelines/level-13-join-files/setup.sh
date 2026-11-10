#!/bin/bash
# Whose Laptop Is That: the DHCP server's lease file (lowercase MACs with
# colons, MAC in field 2) against the asset inventory (uppercase MACs with
# dashes, CSV with a header). New random MACs and IPs on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function hex2() { return sprintf("%02x", int(rand() * 256)) }
BEGIN {
  srand(seed)
  n = split("anna.berg ben.okafor chen.wei dana.kovac elif.yilmaz femi.adeyemi greta.lind hugo.marchetti ines.duarte jonas.weber kofi.mensah lara.novak", owner, " ")
  split("Finance Sales IT Design Support Ops", team, " ")
  split("laptop phone desktop tablet printer", kind, " ")
  vendor[1] = "3c:22:fb"; vendor[2] = "a4:83:e7"; vendor[3] = "f0:18:98"; vendor[4] = "00:1b:63"; vendor[5] = "dc:a6:32"

  # 82 devices: 1-56 leased and in the inventory, 57-66 leased but unknown
  # to the inventory, 67-82 in the inventory but not online today.
  for (i = 1; i <= 82; i++) {
    do { m = vendor[int(rand() * 5) + 1] ":" hex2() ":" hex2() ":" hex2() } while (m in seen)
    seen[m] = 1; mac[i] = m
    o[i] = owner[int(rand() * n) + 1]
  }
  # unique IPs in 10.20.0.0/23
  for (i = 1; i <= 66; i++) {
    do { ip = "10.20." int(rand() * 2) "." (int(rand() * 250) + 2) } while (ip in used)
    used[ip] = 1; addr[i] = ip
  }

  leases = "dnsmasq.leases"
  for (i = 1; i <= 66; i++) order[i] = i
  for (i = 66; i > 1; i--) { j = int(rand() * i) + 1; t = order[i]; order[i] = order[j]; order[j] = t }
  for (k = 1; k <= 66; k++) {
    i = order[k]
    if (i <= 56) { split(o[i], nm, "."); host = kind[int(rand() * 5) + 1] "-" nm[1] }
    else host = (rand() < 0.5) ? "*" : "android-" hex2() hex2() hex2()
    cid = (rand() < 0.7) ? "01:" mac[i] : "*"
    printf "%d %s %s %s %s\n", 1762790400 + int(rand() * 86400), mac[i], addr[i], host, cid > leases
  }

  inv = "inventory.csv"
  print "MAC,owner,team" > inv
  for (i = 1; i <= 82; i++) order[i] = i
  for (i = 82; i > 1; i--) { j = int(rand() * i) + 1; t = order[i]; order[i] = order[j]; order[j] = t }
  for (k = 1; k <= 82; k++) {
    i = order[k]; if (i >= 57 && i <= 66) continue
    m = toupper(mac[i]); gsub(/:/, "-", m)
    printf "%s,%s,%s\n", m, o[i], team[int(rand() * 6) + 1] > inv
  }
}'

cat dnsmasq.leases inventory.csv | cksum > .lm-state/inputs.sum
