#!/bin/bash
# A support queue in arrival order. Ticket ids are random, so sorting on the
# priority alone without -s reorders tickets of the same priority by id (sort
# compares the whole line to break ties), and -k2 without ,2 reorders them by
# customer and subject.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  alnum = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  nc = split("brightwave greenleaf-co hollis-law kappa-labs medora northstar oakridge-clinic pinecrest quayside tessera", cust, " ")
  ns = split("VPN drops every few minutes|Cannot log in after password reset|Invoice PDF is empty|Printer on floor 3 offline|Shared drive is read-only|Laptop fan very loud|Request: new mailbox for intern|Calendar invites not arriving|Payment page shows error 502|Phone extension not ringing|Need access to the sales dashboard|Monitor flickers on dock|Outlook asks for password again|Website down for all customers|Slow file uploads from branch office", subj, "|")
  n = 55 + int(rand() * 25)
  for (i = 1; i <= n; i++) {
    id = "HD-"
    for (k = 1; k <= 5; k++) id = id substr(alnum, int(rand() * 32) + 1, 1)
    r = rand()
    p = (r < 0.12) ? "P1" : (r < 0.40) ? "P2" : (r < 0.80) ? "P3" : "P4"
    printf "%s %s %s %s\n", id, p, cust[int(rand() * nc) + 1], subj[int(rand() * ns) + 1]
  }
}' > queue.txt

cksum < queue.txt > .lm-state/queue.sum
