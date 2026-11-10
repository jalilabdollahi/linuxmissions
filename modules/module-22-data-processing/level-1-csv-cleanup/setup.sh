#!/bin/bash
# Windows CRM export: UTF-8 with a byte-order mark, CRLF line endings and
# empty rows scattered through the file (plus two at the end). Some company
# names are quoted because they contain commas. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

{
  printf '\357\273\277'
  awk -v seed="$RANDOM$$" '
  BEGIN {
    srand(seed)
    nf = split("Anna Bruno Chiara Dmitri Elif Femi Greta Hamid Ines Joao Kenji Lena Mateo Nadia Oskar Priya Quentin Rosa Sven Tomasz Ulla Viktor Wen Yara Zoltan", first, " ")
    nl = split("Abara Becker Costa Dubois Eriksen Fischer Garcia Horvath Ivanova Jensen Kowalski Larsen Moreau Novak Okafor Petrov Rossi Schmidt Tanaka Urbano Vasquez Weber Yilmaz Zhang", last, " ")
    nx = split("Müller|Šimić|Ångström|Nuñez|Øvergaard|Çelik", accented, "|")
    nc = split("Acme Logistics|\"Barnes, Hale & Co\"|Cobalt Systems|Delta Foods|\"Evergreen, Inc.\"|Fjord Shipping|Granite Labs|Helios Energy|\"Ivory, Black and Partners\"|Juniper Health", comp, "|")
    nt = split("Berlin Lisbon Lyon Warsaw Oslo Milan Madrid Vienna Prague Rotterdam Tallinn Porto", city, " ")
    printf "first_name,last_name,email,phone,company,city\r\n"
    rows = 290 + int(rand() * 50)
    for (i = 1; i <= rows; i++) {
      f = first[int(rand() * nf) + 1]
      l = (rand() < 0.12) ? accented[int(rand() * nx) + 1] : last[int(rand() * nl) + 1]
      mail = tolower(substr(f, 1, 1)) "." tolower(l) i "@example.com"
      gsub(/[^a-z0-9.@]/, "x", mail)
      printf "%s,%s,%s,+%d %d %07d,%s,%s\r\n", f, l, mail, 30 + int(rand() * 20), 10 + int(rand() * 89), int(rand() * 9999999), comp[int(rand() * nc) + 1], city[int(rand() * nt) + 1]
      if (rand() < 0.05) printf "\r\n"
    }
    printf "\r\n\r\n"
  }'
} > contacts.csv

cksum < contacts.csv > .lm-state/contacts.sum
