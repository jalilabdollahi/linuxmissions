#!/bin/bash
# Earliest err-or-worse entry, converted to UTC.
ts=$(bin/journalctl --file=export/journal.json -p err -o short-unix -n all --no-pager | head -1 | cut -d. -f1)
first=$(date -u -d @$ts +%Y-%m-%dT%H:%M:%SZ)
# The unit with the huge debug log, and what changed it.
dbg=$(ls -S var/log/*/debug.log | head -1)
cause=$(basename "$(dirname "$dbg")")
if bin/journalctl --file=export/journal.json -g 'rendered /etc' -q --no-pager | grep -q .; then trigger=deploy; else trigger=config-change; fi
# 502s from the first error on: status is field 9, time is local +0100.
n=$(awk '$9 == 502 { print $4, $5 }' var/log/nginx/access.log | tr -d '[]' | sed 's#/# #g; s#:# #' | while read -r d m y h z; do date -u -d "$d $m $y $h $z" +%s; done | awk -v t="$ts" '$1 >= t' | wc -l)
printf 'first_error_utc=%s\nroot_cause_unit=%s.service\ntrigger=%s\nfailed_requests=%s\n' "$first" "$cause" "$trigger" "$n" > incident.txt
cat incident.txt
# The fix.
sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=info/' etc/$cause/env
: > "$dbg"
bin/systemctl restart $cause.service
bin/systemctl reset-failed api.service
bin/systemctl start api.service
