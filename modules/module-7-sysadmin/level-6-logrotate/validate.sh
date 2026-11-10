#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/logrotate.d/myapp"

if [ ! -f "$FILE" ]; then
  echo "❌ logrotate.d/myapp not found"
  exit 1
fi

# Parse the config like logrotate: global directives first, then blocks
# "pattern ... { directives }". Script sections (postrotate..endscript) are skipped.
# Output: ERROR|msg, or one "KEY|value" line per effective setting for the myapp block.
RESULT="$(awk '
  BEGIN {
    split("compress nocompress copy nocopy copytruncate nocopytruncate create nocreate createolddir nocreateolddir " \
          "daily weekly monthly yearly hourly dateext nodateext dateformat dateyesterday delaycompress nodelaycompress " \
          "extension ifempty notifempty mail nomail mailfirst maillast maxage maxsize minage minsize missingok nomissingok " \
          "olddir noolddir postrotate prerotate firstaction lastaction preremove rotate size sharedscripts nosharedscripts " \
          "shred noshred shredcycles start su tabooext taboopat uncompresscmd compresscmd compressext compressoptions " \
          "include renamecopy norenamecopy allowhardlink noallowhardlink ignoreduplicates", k, " ")
    for (i in k) known[k[i]] = 1
    freq = "weekly"; rot = "0"; comp = "no"; miss = "no"; trunc = "no"
    inblock = 0; inscript = 0; blocks = 0; target = 0; others = ""
  }
  function setd(w, arg) {
    if (w ~ /^(daily|weekly|monthly|yearly|hourly)$/) f[scope] = w
    else if (w == "rotate") r[scope] = arg
    else if (w == "compress") c[scope] = "yes"
    else if (w == "nocompress") c[scope] = "no"
    else if (w == "missingok") m[scope] = "yes"
    else if (w == "nomissingok") m[scope] = "no"
    else if (w == "copytruncate") t[scope] = "yes"
    else if (w == "nocopytruncate") t[scope] = "no"
  }
  {
    line = $0
    sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
    if (line == "" || line ~ /^#/) next
    if (inscript) { if (line == "endscript") inscript = 0; next }
    if (!inblock) {
      if (line ~ /\{$/) {
        pats = pats " " substr(line, 1, length(line) - 1)
        gsub(/"/, "", pats); n = split(pats, pp, /[[:space:]]+/)
        blocks++; scope = "b" blocks; inblock = 1; hit = 0
        for (i = 1; i <= n; i++) if (pp[i] != "") {
          if (pp[i] == "/var/log/myapp/*.log") hit = 1
          else if (pp[i] ~ /^\/var\/log\/myapp\//) others = others " " pp[i]
        }
        if (hit) { if (target) dup = 1; target = scope }
        pats = ""; next
      }
      if (line ~ /^\// || line ~ /^"/) { pats = pats " " line; next }
      if (line == "{") { print "ERROR|put the opening { on the same line as the log file pattern"; bad = 1; exit }
      scope = "global"
    } else if (line == "}") { inblock = 0; next }
    if (line ~ /\}/ || line ~ /\{/) { print "ERROR|braces must be on their own: pattern {  ...  }"; bad = 1; exit }
    split(line, w, /[[:space:]]+/)
    if (!(w[1] in known)) { print "ERROR|unknown directive \"" w[1] "\""; bad = 1; exit }
    if (w[1] ~ /^(postrotate|prerotate|firstaction|lastaction|preremove)$/) { inscript = 1; next }
    if (w[1] == "rotate" && w[2] !~ /^-?[0-9]+$/) { print "ERROR|rotate needs a number"; bad = 1; exit }
    setd(w[1], w[2])
  }
  END {
    if (bad) exit
    if (inblock) { print "ERROR|a block is missing its closing }"; exit }
    if (inscript) { print "ERROR|a script section is missing endscript"; exit }
    if (dup) { print "ERROR|/var/log/myapp/*.log appears in more than one block"; exit }
    if (!target) { print "ERROR|no block covers every .log file in /var/log/myapp"; exit }
    if (others != "") { print "ERROR|other /var/log/myapp patterns remain:" others " (logrotate rejects files matched twice)"; exit }
    s = target
    print "freq|" ((s in f) ? f[s] : ("global" in f) ? f["global"] : freq)
    print "rotate|" ((s in r) ? r[s] : ("global" in r) ? r["global"] : rot)
    print "compress|" ((s in c) ? c[s] : ("global" in c) ? c["global"] : comp)
    print "missingok|" ((s in m) ? m[s] : ("global" in m) ? m["global"] : miss)
    print "copytruncate|" ((s in t) ? t[s] : ("global" in t) ? t["global"] : trunc)
  }' "$FILE")"

if printf '%s\n' "$RESULT" | grep -q '^ERROR|'; then
  echo "❌ $(printf '%s\n' "$RESULT" | grep '^ERROR|' | head -n 1 | cut -d'|' -f2-)"
  exit 1
fi
get() { printf '%s\n' "$RESULT" | grep "^$1|" | cut -d'|' -f2; }

if [ "$(get freq)" != "daily" ]; then
  echo "❌ the myapp logs are rotated $(get freq), not daily"
  exit 1
fi
if [ "$(get rotate)" != "14" ]; then
  echo "❌ the config keeps $(get rotate) old logs, not 14"
  exit 1
fi
if [ "$(get compress)" != "yes" ]; then
  echo "❌ rotated logs are not compressed"
  exit 1
fi
if [ "$(get missingok)" != "yes" ]; then
  echo "❌ logrotate would report an error when a log file is missing"
  exit 1
fi
if [ "$(get copytruncate)" != "yes" ]; then
  echo "❌ myapp never reopens its log files, so moving them away is not enough (it would keep writing to the rotated file)"
  exit 1
fi

echo "✅ logrotate.d/myapp rotates every myapp log daily, keeps 14 compressed copies, and works with an app that never reopens its logs"
exit 0
