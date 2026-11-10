#!/bin/bash
# Weekly Bounce Report: two mail relays (var/log/mail.log* and
# var/log/mx2/mail.log*) with daily rotation, rotated logs
# gzipped from .2 on. Files .0-.7 were modified in the last 7 days, .8+ are
# older. Sender (from=) and result (status=) are on different lines, linked
# by the queue ID, sometimes across files. The bounce counts per sender
# domain are planned so that every classic slip changes the top 5: old logs,
# the mx2 directory, the .gz files, the empty sender <>, mixed-case domains,
# recipient domains and a tie at rank 5/6. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state var/log/mx2

NOW=$(date +%s)
# Last rotation 4 hours ago, so .7 (6 days 4 hours old) stays inside and .8
# outside the 7-day window for the whole session.
R0=$(( NOW - 14400 - NOW % 900 ))
OLDEST=$(( R0 - 10 * 86400 ))
M0=$(( OLDEST / 86400 * 86400 ))
LABELS=""
for d in $(seq 0 12); do
  e=$(( M0 + d * 86400 ))
  l=$(date -u -d "@$e" '+%b %e' 2>/dev/null || date -u -r "$e" '+%b %e')
  LABELS="$LABELS$l|"
done
stamp() { date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S; }

awk -v seed="$RANDOM$$" -v now="$NOW" -v r0="$R0" '
function qid(   s, i) { do { s = ""; for (i = 0; i < 10; i++) s = s substr("0123456789ABCDEF", int(rand() * 16) + 1, 1) } while (s in used); used[s] = 1; return s }
function mixcase(d,   r) { r = rand(); if (r < 0.6) return d; if (r < 0.8) return toupper(substr(d, 1, 1)) substr(d, 2); return toupper(d) }
function ev(t, srv, text) { printf "%d\t%s\t%s\n", t, srv, text }
# one message; status "sent" or "bounced"; t = time of the final result
function msg(srv, t, sender, status,   q, rc, rd, tf, nd, j, pid) {
  q = qid(); rd = rcpt[int(rand() * nrc) + 1]
  rc = substr("abcdefghijklmnopqrstuvwxyz", int(rand() * 26) + 1, 1) substr("aeiou", int(rand() * 5) + 1, 1) "." user[int(rand() * nus) + 1] "@" rd
  nd = (rand() < 0.2) ? 1 + int(rand() * 3) : 0
  tf = t - 1 - int(rand() * 20) - nd * (1800 + int(rand() * 5400))
  if (tf < lo) tf = lo
  ev(tf - 1, srv, "postfix/cleanup[" (3000 + int(rand() * 900)) "]: " q ": message-id=<" int(rand() * 1e9) "." q "@" (sender == "" ? srv ".example.net" : tolower(substr(sender, index(sender, "@") + 1))) ">")
  ev(tf, srv, "postfix/qmgr[1187]: " q ": from=<" sender ">, size=" (900 + int(rand() * 90000)) ", nrcpt=1 (queue active)")
  for (j = 1; j <= nd; j++)
    ev(tf + j * int((t - tf) / (nd + 1)), srv, "postfix/smtp[" (4000 + int(rand() * 900)) "]: " q ": to=<" rc ">, relay=none, delay=" (j * 1800) ", delays=0.1/0/" (j * 1800) "/0, dsn=4.4.1, status=deferred (connect to mx." rd "[198.51.100." int(rand() * 250) "]:25: Connection timed out)")
  pid = 4000 + int(rand() * 900)
  if (status == "sent")
    ev(t, srv, "postfix/smtp[" pid "]: " q ": to=<" rc ">, relay=mx." rd "[203.0.113." int(rand() * 250) "]:25, delay=" sprintf("%.1f", (t - tf) + rand()) ", delays=0.1/0.01/0.3/0.4, dsn=2.0.0, status=sent (250 2.0.0 OK queued as " qid() ")")
  else {
    ev(t, srv, "postfix/smtp[" pid "]: " q ": to=<" rc ">, relay=mx." rd "[203.0.113." int(rand() * 250) "]:25, delay=" sprintf("%.1f", (t - tf) + rand()) ", delays=0.1/0.01/0.3/0.4, dsn=5.1.1, status=bounced (host mx." rd " said: 550 5.1.1 <" rc ">: Recipient address rejected: User unknown in virtual mailbox table (in reply to RCPT TO command))")
    ev(t, srv, "postfix/bounce[" (5000 + int(rand() * 900)) "]: " q ": sender non-delivery notification: " qid())
  }
  ev(t, srv, "postfix/qmgr[1187]: " q ": removed")
}
function sender_of(d) { return local[int(rand() * nlo) + 1] "@" mixcase(d) }
BEGIN {
  srand(seed)
  nrc = split("gmail.com outlook.com yahoo.com gmx.de web.de icloud.com proton.me hotmail.co.uk orange.fr libero.it", rcpt, " ")
  nus = split("smith jones meyer rossi dubois novak berg kim silva tan", user, " ")
  nlo = split("billing noreply news alerts jobs info support invoices", local, " ")
  nd = split("acme-shop.example newsletter.acme-shop.example billing.hostco.example alerts.monitorly.example crm.salesforge.example hr.peoplehub.example noreply.ticketdesk.example jobs.hireflow.example events.meetly.example", dom, " ")
  for (i = nd; i > 1; i--) { j = int(rand() * i) + 1; t = dom[i]; dom[i] = dom[j]; dom[j] = t }
  win = r0 - 7 * 86400; old = r0 - 10 * 86400

  # Planned bounce counts inside the window: c[1] > c[2] > ... with a tie
  # between rank 5 and rank 6, decided by the domain name.
  c[1] = 24 + int(rand() * 8)
  for (i = 2; i <= 5; i++) c[i] = c[i - 1] - 1 - int(rand() * 3)
  c[6] = c[5]
  c[7] = c[5] - 2 - int(rand() * 2); c[8] = 3 + int(rand() * 3)
  for (i = 1; i <= 8; i++) {
    # the second-ranked domain sends mostly through mx2
    for (k = 0; k < c[i]; k++) {
      srv = (i == 2) ? (rand() < 0.8 ? "mx2" : "mx1") : (rand() < 0.25 ? "mx2" : "mx1")
      lo = win + 60; msg(srv, win + 7200 + int(rand() * (now - win - 7300)), sender_of(dom[i]), "bounced")
    }
  }
  # bounces of the empty sender (non-delivery notices that bounced themselves)
  for (k = 0; k < c[1] + 3; k++) { lo = win + 60; msg(rand() < 0.3 ? "mx2" : "mx1", win + 7200 + int(rand() * (now - win - 7300)), "", "bounced") }
  # a bad newsletter run 8-10 days ago: lots of bounces, but outside the window
  for (k = 0; k < 40; k++) { lo = old + 60; msg("mx1", old + 7200 + int(rand() * (win - old - 14400)), sender_of(dom[9]), "bounced") }
  # normal traffic over all days, both relays
  for (k = 0; k < 1800; k++) {
    s = (rand() < 0.05) ? "" : sender_of(dom[int(rand() * nd) + 1])
    if (rand() < 0.7) { lo = win + 60; t = win + 7200 + int(rand() * (now - win - 7300)) }
    else { lo = old + 60; t = old + 7200 + int(rand() * (win - old - 14400)) }
    msg(rand() < 0.3 ? "mx2" : "mx1", t, s, "sent")
  }
}' > .lm-state/events

# Write the events into rotated files: k = 0 for the current file, k = 1 for
# the day before the last rotation, and so on.
sort -s -n -k1,1 .lm-state/events | awk -F'\t' -v r0="$R0" -v m0="$M0" -v labels="$LABELS" '
BEGIN { split(labels, lab, "|") }
{
  e = $1; k = (e >= r0) ? 0 : int((r0 - e - 1) / 86400) + 1
  d = int((e - m0) / 86400); s = (e - m0) % 86400
  f = ($2 == "mx2" ? "var/log/mx2/mail.log" : "var/log/mail.log") (k ? "." k : "")
  printf "%s %02d:%02d:%02d %s %s\n", lab[d + 1], int(s / 3600), int(s / 60) % 60, s % 60, $2, $3 > f
}'
rm .lm-state/events

# Other logs next to them, so a careless glob or find picks up the wrong files.
printf '%s mx1 postfix/smtpd[2901]: warning: hostname 203-0-113-9.example.net does not resolve to address 203.0.113.9\n' "$(date -u '+%b %e %H:%M:%S')" > var/log/mail.err
printf '%s mx1 CRON[3311]: (root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)\n' "$(date -u '+%b %e %H:%M:%S')" > var/log/syslog

# Compress from .2 on, then set the mtimes logrotate would have left.
for f in var/log/mail.log.* var/log/mx2/mail.log.*; do
  k=${f##*.}
  [ "$k" -ge 2 ] && gzip -n "$f" && f="$f.gz"
  touch -t "$(stamp $(( R0 - (k - 1) * 86400 - 30 )))" "$f"
done
touch -t "$(stamp $(( NOW - 60 )))" var/log/mail.log var/log/mx2/mail.log var/log/mail.err var/log/syslog

# The files that count: modified in the 7 days before setup (kept, so the
# answer doesn't drift if the player takes a while).
(cd var/log && find . -name 'mail.log*' -mtime -7 | sed 's|^\./|var/log/|' | sort) > .lm-state/window
(cd var/log && find . -name 'mail.log*' | sed 's|^\./|var/log/|' | sort) > .lm-state/all
find var/log -type f -exec cksum {} + | sort > .lm-state/logs.sum
