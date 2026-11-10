#!/bin/bash
# report.txt = top 5 sender domains by bounced messages, from the mail logs
# (plain and .gz, both relays) modified in the 7 days before setup. Each
# bounced queue ID counts once for the domain of its from= address (lowercase,
# empty sender <> excluded). Ties broken by domain name. Lines: rank domain count.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/window ] || [ ! -s .lm-state/all ] || [ ! -s .lm-state/logs.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ "$(find var/log -type f -exec cksum {} + 2>/dev/null | sort)" != "$(cat .lm-state/logs.sum)" ]; then
  echo "❌ the logs under var/log were changed, moved or unpacked in place; type 'reset' to restore them (zcat / gzip -cd read .gz files without unpacking)"
  exit 1
fi
if [ ! -f report.txt ]; then
  echo "❌ report.txt does not exist yet"
  exit 1
fi

# top5 MODE FILE...   MODE: ok | nolower | rcpt
top5() {
  local mode=$1; shift
  for f in "$@"; do gzip -cdf "$f"; done | awk -v mode="$mode" '
    { q = $6; sub(/:$/, "", q) }
    / from=</ { s = $0; sub(/.*from=</, "", s); sub(/>.*/, "", s); d = index(s, "@") ? substr(s, index(s, "@") + 1) : ""; from[q] = (mode == "nolower") ? d : tolower(d) }
    /status=bounced/ { b[q] = 1; r = $0; sub(/.* to=<[^@]*@/, "", r); sub(/>.*/, "", r); to[q] = tolower(r) }
    END {
      for (q in b) { d = (mode == "rcpt") ? to[q] : from[q]; if (d != "") n[d]++ }
      for (d in n) print d, n[d]
    }' | LC_ALL=C sort -k2,2nr -k1,1 | head -5 | awk '{ print NR, $1, $2 }'
}

WINDOW=$(cat .lm-state/window)
EXPECTED=$(top5 ok $WINDOW)
GOT=$(tr -d '\r' < report.txt | awk 'NF { $1 = $1; print }')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ report.txt has this week's top 5 bouncing sender domains: $(printf '%s\n' "$EXPECTED" | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $2 }')"
  exit 0
fi

if [ -z "$GOT" ]; then
  echo "❌ report.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | awk 'NF != 3 || $1 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ { f = 1 } END { exit !f }'; then
  if printf '%s\n' "$GOT" | awk 'NF == 2 || $2 == "<>" { f = 1 } END { exit !f }'; then
    echo "❌ a line of report.txt has no domain: bounces of the empty sender from=<> (bounce notices that bounced) have no sender domain, leave them out"
  else
    echo "❌ every line of report.txt must be 'rank domain count', e.g. '1 example.org 17'"
  fi
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')" -ne 5 ]; then
  echo "❌ report.txt has $(printf '%s\n' "$GOT" | wc -l | tr -d ' ') lines; the report is the top 5"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | awk '{ printf "%s ", $1 }')" != "1 2 3 4 5 " ]; then
  echo "❌ the first column must be the rank: 1, 2, 3, 4, 5"
  exit 1
fi
if printf '%s\n' "$GOT" | awk '$2 ~ /[A-Z]/ { f = 1 } END { exit !f }'; then
  echo "❌ report.txt has domains with capital letters: Billing@HostCo.example and billing@hostco.example are the same domain, count them together in lowercase"
  exit 1
fi

PLAIN=$(printf '%s\n' "$WINDOW" | grep -v '\.gz$')
MX1=$(printf '%s\n' "$WINDOW" | grep -v '/mx2/')
same() { [ "$GOT" = "$1" ]; }
if same "$(top5 ok $(cat .lm-state/all))"; then
  echo "❌ report.txt counts every mail log, including the rotated ones older than 7 days: keep only files modified in the last 7 days"
elif same "$(top5 ok $MX1)"; then
  echo "❌ report.txt misses the logs of the second relay: find searches the subdirectories of var/log too"
elif same "$(top5 ok $PLAIN)"; then
  echo "❌ report.txt misses the compressed logs: the .gz files of this week must be read too (zcat -f / gzip -cdf)"
elif same "$(top5 ok var/log/mail.log)"; then
  echo "❌ report.txt only covers the current var/log/mail.log; the week is spread over the rotated files"
elif same "$(top5 rcpt $WINDOW)"; then
  echo "❌ those are recipient domains (to=); the report wants the domain of the sender (from=), found on the from= line with the same queue ID"
elif [ "$(printf '%s\n' "$GOT" | awk '{ print $2, $3 }' | sort)" = "$(printf '%s\n' "$EXPECTED" | awk '{ print $2, $3 }' | sort)" ]; then
  echo "❌ the right domains and counts, but in the wrong order: highest count first, equal counts by domain name (a to z)"
elif [ "$(printf '%s\n' "$GOT" | head -4)" = "$(printf '%s\n' "$EXPECTED" | head -4)" ] && [ "$(printf '%s\n' "$GOT" | awk 'NR == 5 { print $3 }')" = "$(printf '%s\n' "$EXPECTED" | awk 'NR == 5 { print $3 }')" ]; then
  echo "❌ rank 5 is a tie between two domains with the same count: break ties by domain name, a to z"
else
  w=$(printf '%s\n' "$GOT" | awk 'NR == FNR { c[$2] = $3; next } !($2 in c) || c[$2] != $3 { print $2; exit }' <(printf '%s\n' "$EXPECTED") -)
  echo "❌ the line for ${w:-a domain} is not right; count each bounced message (queue ID) once, for the sender domain of its from= line in lowercase"
fi
exit 1
