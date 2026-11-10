#!/bin/bash
# Is It Beaconing? Two hours of the quarantined laptop's local dnsmasq log.
# Names keep the case the application used, some carry a trailing dot, and
# every query is followed by forwarded/reply or cached lines that repeat the
# name. Random counts and beacon names on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function variant(d,   r, u, i, c) {
  r = rand()
  if (r < 0.70) return d
  if (r < 0.82) return d "."
  if (r < 0.92) { u = ""; for (i = 1; i <= length(d); i++) { c = substr(d, i, 1); u = u ((rand() < 0.5) ? toupper(c) : c) } return u }
  return toupper(d)
}
function rnd(n,   s, i) { s = ""; for (i = 0; i < n; i++) s = s substr("abcdefghijklmnopqrstuvwxyz0123456789", int(rand() * 36) + 1, 1); return s }
function add(d, n,   i) { for (i = 0; i < n; i++) { q[++nq] = d; t[nq] = int(rand() * 7200) } }
BEGIN {
  srand(seed)
  nl = split("www.google.com fonts.googleapis.com api.github.com github.com outlook.office365.com login.microsoftonline.com teams.microsoft.com slack.com edge.slack.com wss-primary.slack.com www.wikipedia.org en.wikipedia.org stackoverflow.com cdn.jsdelivr.net registry.npmjs.org pypi.org files.pythonhosted.org update.code.visualstudio.com marketplace.visualstudio.com ntp.ubuntu.com archive.ubuntu.com security.ubuntu.com connectivity-check.ubuntu.com www.bbc.co.uk news.ycombinator.com docs.python.org zoom.us us05web.zoom.us drive.google.com mail.google.com accounts.google.com calendar.google.com jira.example.org wiki.example.org vpn.example.org intranet.example.org grafana.example.org gitlab.example.org s3.eu-central-1.amazonaws.com sentry.io", legit, " ")
  # legit traffic: most names a handful of times, some exactly once or twice
  for (i = 1; i <= nl; i++) {
    r = rand()
    n = (r < 0.30) ? 1 : (r < 0.50) ? 2 : 3 + int(rand() * 18)
    add(legit[i], n)
  }
  # the beacons: random subdomains of look-alike domains, queried regularly
  split("cdn-telemetry.top update-check.xyz metrics-sync.click", evil, " ")
  for (i = 1; i <= 3; i++) {
    d = rnd(6 + int(rand() * 4)) "." evil[i]; n = 6 + int(rand() * 18)
    off = int(rand() * 300); gap = int(7200 / n)
    for (j = 0; j < n; j++) { q[++nq] = d; t[nq] = off + j * gap + int(rand() * 20) }
  }
  # one-off lookups with random names (a scanner, typos)
  for (i = 1; i <= 12; i++) add(rnd(4 + int(rand() * 6)) ".example.net", 1)
  # traps: a name looked up exactly twice in two spellings, and one three
  # times in three spellings
  q[++nq] = "Docs.GitHub.com"; t[nq] = int(rand() * 7200)
  q[++nq] = "docs.github.com."; t[nq] = int(rand() * 7200)
  q[++nq] = "Status.Example.ORG"; t[nq] = int(rand() * 7200)
  q[++nq] = "status.example.org."; t[nq] = int(rand() * 7200)
  q[++nq] = "status.example.org"; t[nq] = int(rand() * 7200)

  for (i = 1; i <= nq; i++) {
    name = (q[i] ~ /[A-Z]|\.$/) ? q[i] : variant(q[i])
    key = sprintf("%05d %06d", t[i], i)
    line[key] = name
  }
  n = 0; for (k in line) keys[++n] = k
  # sort the keys (insertion sort is fine for a few hundred lines)
  for (i = 2; i <= n; i++) { v = keys[i]; for (j = i - 1; j > 0 && keys[j] > v; j--) keys[j + 1] = keys[j]; keys[j + 1] = v }
  for (i = 1; i <= n; i++) {
    split(keys[i], kk, " "); s = 32400 + kk[1]; name = line[keys[i]]
    ts = sprintf("Nov 10 %02d:%02d:%02d dnsmasq[812]:", int(s / 3600), int(s / 60) % 60, s % 60)
    type = (rand() < 0.7) ? "A" : "AAAA"
    printf "%s query[%s] %s from 127.0.0.1\n", ts, type, name
    addr = (type == "A") ? sprintf("%d.%d.%d.%d", 13 + int(rand() * 200), int(rand() * 256), int(rand() * 256), 1 + int(rand() * 254)) : sprintf("2a00:1450:4001:%x::200e", int(rand() * 4096))
    if (rand() < 0.4) printf "%s cached %s is %s\n", ts, name, addr
    else {
      printf "%s forwarded %s to 10.0.0.53\n", ts, name
      printf "%s reply %s is %s\n", ts, name, addr
    }
  }
}' > dnsmasq.log

cksum < dnsmasq.log > .lm-state/log.sum
