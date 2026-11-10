#!/bin/bash
# Usernames From HR: the new-hire list as HR's Windows tool exports it, with
# CRLF line endings, tabs or double spaces between name parts, initials with
# dots and inconsistent capitals. New names on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function cap(s) { return toupper(substr(s, 1, 1)) substr(s, 2) }
function style(s,   r) { r = rand(); if (r < 0.75) return cap(s); if (r < 0.9) return toupper(s); return s }
function sep(   r) { r = rand(); if (r < 0.6) return " "; if (r < 0.75) return "  "; if (r < 0.9) return "\t"; return " \t" }
BEGIN {
  srand(seed)
  nf = split("anna ben chiara dmitri emeka fatima gustav hana ivan julia kenji leila marco nadia oscar priya quentin rosa samir tomas ulrike vikram wanda xavier yusuf zoe jean-luc anne-marie", first, " ")
  nl = split("berg okafor rossi petrov nwosu haddad lindqvist sato horvat novak tanaka karimi bianchi schmidt dubois sharma moreau garcia mansour kowalski weber patel nowak fischer yilmaz brandt van-dijk", last, " ")
  for (i = 1; i <= 64; i++) {
    name = style(first[int(rand() * nf) + 1])
    r = rand()
    if (r < 0.2) name = name sep() toupper(substr("abcdefghjklmnprstw", int(rand() * 18) + 1, 1)) "."
    else if (r < 0.3) name = name sep() style(first[int(rand() * nf) + 1])
    name = name sep() style(last[int(rand() * nl) + 1])
    if (rand() < 0.08) name = toupper(substr(name, 1, 1)) "." toupper(substr("abcdefghjklmnprstw", int(rand() * 18) + 1, 1)) "." sep() style(last[int(rand() * nl) + 1])
    printf "%s\r\n", name
  }
}' > newhires.txt

cksum < newhires.txt > .lm-state/newhires.sum
