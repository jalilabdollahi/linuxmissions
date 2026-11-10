#!/bin/bash
# Helpdesk Export: a CSV where the quoted notes field (and sometimes the
# subject) contains line breaks, commas and escaped quotes (""), including
# continuation lines that end in "" or start with a ticket id. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function csv(s,   t) { t = s; if (t ~ /[",\n]/) { gsub(/"/, "\"\"", t); t = "\"" t "\"" } return t }
function pick(a, n) { return a[int(rand() * n) + 1] }
BEGIN {
  srand(seed)
  ns = split("VPN drops every 10 minutes|Printer on 3rd floor offline|Outlook keeps asking for password|New starter, needs laptop and badge|Excel crashes on save|Cannot reach intranet|Shared drive is read-only|Teams camera not detected|Password reset|Monitor flickering, cable swapped|Request: admin rights for installer|Disk full on build agent", subj, "|")
  nr = split("a.berg k.mensah l.novak t.holm o.falk m.engel s.kaya r.costa n.lund y.vogel", req, " ")
  nn = split("Called the user, could not reproduce.|User says the error reads \"access denied\".|Restarted the spooler service.|Replaced the dock, still the same.|Escalated to network team, waiting.|Customer wrote: it says \"disk full\"|Asked for a screenshot.|Reinstalled the client, cleared the cache, rebooted.|Linked: TCK-10233 was the same issue.|Works from home, not from the office.|\"Temporary\" fix applied, monitor this week.|Closed after no reply, 3 reminders sent.", note, "|")
  split("open|pending|closed|closed|closed", st, "|")
  print "ticket_id,opened,requester,subject,notes,status"
  n = 160 + int(rand() * 60)
  for (i = 1; i <= n; i++) {
    k = int(rand() * 4)
    txt = ""
    for (j = 0; j <= k; j++) {
      piece = pick(note, nn)
      if (j == 0) txt = piece
      else txt = txt ((rand() < 0.6) ? "\n" : (rand() < 0.5 ? " " : "\n\n")) piece
    }
    if (rand() < 0.08) txt = ""
    if (i % 23 == 5) txt = "Customer wrote: it says \"disk full\"\nTCK-" (10000 + i - 3) " has the details."
    s = pick(subj, ns)
    if (rand() < 0.05) s = s "\nsecond line from the web form"
    printf "TCK-%d,2026-10-%02d %02d:%02d,%s,%s,%s,%s\n", 10000 + i, 1 + int(i * 30 / n), 8 + int(rand() * 9), int(rand() * 60), pick(req, nr), csv(s), csv(txt), pick(st, 5)
  }
}' > tickets.csv

cksum < tickets.csv > .lm-state/tickets.sum
