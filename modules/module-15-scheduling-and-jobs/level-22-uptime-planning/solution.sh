#!/bin/bash
printf '%s\n' 2026-10-28 2026-10-29 2026-10-30 2026-11-01 2026-11-02 2026-11-03 2026-11-04 2026-11-05 2026-11-06 2026-11-07 2026-11-09 2026-11-10 > missed.txt
printf '1\t10\tbuild-nightly\t/opt/build/nightly.sh --full >> /var/log/build/nightly.log 2>&1\n' >> anacrontab
grep -v 'nightly.sh' crontab.txt > crontab.new && cat crontab.new > crontab.txt && rm crontab.new
