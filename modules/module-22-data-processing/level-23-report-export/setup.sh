#!/bin/bash
# Two Exports: a cleaned TSV of invoices with UTF-8 names, company names and
# notes containing commas and double quotes, ZIP codes with leading zeros,
# negative and fractional amounts, and empty notes. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function pick(a, n) { return a[int(rand() * n) + 1] }
BEGIN {
  srand(seed)
  nn = split("Zoë Laurent|Søren Kjær|Łukasz Nowak|José Álvarez|Chloé Martin|Björn Åström|Ana Müller|Siobhán O'\''Brien|Mia Chen|Noah Becker|Emma Dubois|Liam Walsh|Ines Duarte|Kofi Mensah|Yuki Tanaka", nm, "|")
  nc = split("Acme, Inc.|Bauer & Söhne GmbH|The \"Blue Door\" Café|Northwind Traders|Smith, Jones & Partners|Contoso Ltd|Fabrikam|Café Zürich AG|\"Best\" Bikes, LLC|Litware", co, "|")
  nt = split("Boston|Cambridge|Newton|Somerville|Brookline|Holtsville|Portsmouth|Burlington", city, "|")
  split("02134|02139|02458|02143|02445|00501|03801|05401", zip, "|")
  no = split("rush order, call before delivery|customer says \"urgent\"|net 30|||paid by card, receipt sent|\"VIP\" account|split shipment, 2 boxes||", note, "|")
  printf "id\tname\tcompany\tcity\tzip\tamount\tnote\n"
  n = 45 + int(rand() * 25)
  for (i = 1; i <= n; i++) {
    c = int(rand() * nt) + 1
    r = rand()
    amt = (r < 0.1) ? sprintf("-%d.%02d", 10 + int(rand() * 300), int(rand() * 100)) : (r < 0.2) ? sprintf("0.%02d", 1 + int(rand() * 98)) : sprintf("%d.%02d", 20 + int(rand() * 9000), int(rand() * 100))
    printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\n", 7000 + i * 3 + int(rand() * 3), pick(nm, nn), pick(co, nc), city[c], zip[c], amt, pick(note, no)
  }
}' > clean.tsv

cksum < clean.tsv > .lm-state/clean.sum
