#!/bin/bash
# 1. Reproduce: only cron's variables, comment line dropped, both streams logged.
env -i $(grep -v '^#' cron.env) ./report-gen > cron-run.log 2>&1
cat cron-run.log
# 2. Fix: cron sets LOGNAME but not USER, and there is no TERM for tput.
sed -i.bak -e 's/^author="\$USER"$/author="${USER:-$LOGNAME}"/' \
           -e 's/^width=\$(tput cols)$/width=$(tput cols 2>\/dev\/null || echo 80)/' report-gen
rm -f report-gen.bak
# 3. Try again the way cron would.
env -i $(grep -v '^#' cron.env) ./report-gen | tail -2
