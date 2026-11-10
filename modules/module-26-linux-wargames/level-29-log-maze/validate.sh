#!/bin/bash
SB="$1"; cd "$SB" || exit 1
for f in rootcause.txt timeline.tsv; do [ -s "$f" ] || { echo "❌ $f is missing or empty"; exit 1; }; done
tr -d '\r' < rootcause.txt | sed 's/[[:space:]]*$//' > .lm/got-rc.txt
if [ "$(head -1 .lm/got-rc.txt)" != "inventory" ]; then echo "❌ rootcause.txt names the wrong service (the first ERROR on a failing request, in UTC order, not the loudest service)"; exit 1; fi
if [ "$(wc -l < .lm/got-rc.txt)" -ne 2 ] || [ "$(sed -n 2p .lm/got-rc.txt)" != "$(sed -n 2p .lm/rootcause.txt)" ]; then echo "❌ rootcause.txt has the right service but line 2 is not the earliest ERROR line of a failing request, copied verbatim"; exit 1; fi
tr -d '\r' < timeline.tsv | sed 's/[[:space:]]*$//' > .lm/got-tl.tsv
exp=$(wc -l < .lm/timeline.tsv); got=$(wc -l < .lm/got-tl.tsv)
if [ "$got" -ne "$exp" ]; then echo "❌ timeline.tsv has $got line(s) but the request has $((exp)) log events (one line per event, a stack trace is not an event of its own)"; exit 1; fi
if ! cmp -s <(cut -f2,3 .lm/got-tl.tsv) <(cut -f2,3 .lm/timeline.tsv); then echo "❌ timeline.tsv has the wrong services/levels or the events are out of order"; exit 1; fi
if ! cmp -s .lm/got-tl.tsv .lm/timeline.tsv; then echo "❌ timeline.tsv has the right events but some times are wrong (check each log's time zone and the YYYY-MM-DDTHH:MM:SS.mmmZ format)"; exit 1; fi
echo "✅ root cause and timeline are exact"
