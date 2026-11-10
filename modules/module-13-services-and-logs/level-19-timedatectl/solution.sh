#!/bin/bash
# The kill time is UTC; the app logs local time without an offset. Ask the
# (mock) timedatectl for the zone, convert, and grep that second.
bin/timedatectl
zone=$(bin/timedatectl show | sed -n 's/^Timezone=//p')
utc=$(grep 'Killed process' kernel-oom.txt | cut -d' ' -f1)
local_ts=$(TZ="$zone" date -d "$utc" '+%Y-%m-%d %H:%M:%S')
echo "$utc -> $local_ts $zone"
grep "^$local_ts " var/log/imgproxy/app.log > match.txt
cat match.txt
