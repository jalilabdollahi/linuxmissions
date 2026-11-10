#!/bin/bash
# Which unit's main process maps the deleted libssl? Ask each unit for its PID.
for u in $(ls etc/systemd/system/*.service | xargs -n1 basename); do
  pid=$(bin/systemctl show -P MainPID "$u")
  grep -q 'libssl.*(deleted)' /proc/$pid/maps 2>/dev/null && echo "$u"
done > needs-restart.txt
cat needs-restart.txt
xargs -n1 bin/systemctl restart < needs-restart.txt
