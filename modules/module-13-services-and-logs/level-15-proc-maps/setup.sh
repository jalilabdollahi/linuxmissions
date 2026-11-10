#!/bin/bash
# Stale libssl: the libssl3 package was upgraded an hour ago (the file was
# replaced, as dpkg does: new file written, renamed over the old one), but
# the services were not restarted. Several of them still map the old,
# now deleted, copy: "libssl.so.3 (deleted)" in /proc/PID/maps.
#   - affected (2-4 random units): started before the upgrade, mmap the lib;
#   - fresh: started after the upgrade, maps the new file at the same path;
#   - fd-only: opened the old file and holds the descriptor, but never
#     mapped it: /proc/PID/fd shows "(deleted)", /proc/PID/maps does not.
# Names and roles are random per setup. Mock systemctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state etc/systemd/system/multi-user.target.wants opt/svc/bin usr/lib/x86_64-linux-gnu
cp "$M/systemd/systemctl" bin/
echo app-03 > etc/hostname
echo "2026-11-10 14:20:00" > .lm/now

LIB=usr/lib/x86_64-linux-gnu/libssl.so.3

cat > opt/svc/bin/svc <<'PY'
#!/usr/bin/env python3
# Stand-in for a daemon: svc NAME LIBRARY [map|fd]
# map: mmap the library (like the dynamic loader does); fd: only keep it open.
import mmap, os, sys, time
name, lib = sys.argv[1], sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else "map"
f = open(lib, "rb")
if mode == "map":
    keep = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    f.close()
print("%s: started, libssl loaded (%s)" % (name, mode), flush=True)
while True:
    time.sleep(30)
PY
chmod +x opt/svc/bin/svc

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
names = R.sample(["api", "worker", "mailer", "scheduler", "webhooks", "exporter", "gateway", "notifier", "indexer"], 7)
n_aff = R.choice([2, 3, 4])
aff = names[:n_aff]
fresh = names[n_aff]
fdonly = names[n_aff + 1]
rest = names[n_aff + 2:]          # started before the upgrade, never mapped it (statically linked)
roles = {}
for n in aff: roles[n] = "map-old"
roles[fresh] = "map-new"
roles[fdonly] = "fd"
for n in rest: roles[n] = "nolib"
order = sorted(roles)
with open(".lm-state/roles", "w") as f:
    for n in order:
        f.write("%s.service %s\n" % (n, roles[n]))
PY

# A fake 'old' and 'new' library: just bytes, mapped read-only.
head -c 262144 /dev/urandom > "$LIB"
head -c 262144 /dev/urandom > .lm-state/libssl.new

while read -r unit role; do
  name=${unit%.service}
  case $role in
    fd)    mode=fd ;;
    nolib) mode=none ;;
    *)     mode=map ;;
  esac
  if [ "$mode" = none ]; then
    exec_line="/usr/bin/sleep 100000"
  else
    exec_line="/opt/svc/bin/svc $name /usr/lib/x86_64-linux-gnu/libssl.so.3 $mode"
  fi
  cat > etc/systemd/system/$unit <<UNIT
[Unit]
Description=$name ($(case $role in nolib) echo "static binary";; *) echo "uses libssl";; esac))
After=network.target

[Service]
Type=simple
ExecStart=$exec_line
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
  ln -s /etc/systemd/system/$unit etc/systemd/system/multi-user.target.wants/$unit
done < .lm-state/roles
bin/systemctl daemon-reload

pid_of() { bin/systemctl show -P MainPID "$1"; }
wait_map() {   # wait until PID has mapped (or opened) the library
  for _ in $(seq 1 100); do
    grep -q libssl "/proc/$1/maps" 2>/dev/null || [ -n "$(ls -l /proc/$1/fd 2>/dev/null | grep libssl)" ] && return 0
    sleep 0.1
  done
  return 1
}

# Before the upgrade: everything that needs libssl starts and loads it.
while read -r unit role; do
  case $role in map-new) continue ;; esac
  bin/systemctl start "$unit"
done < .lm-state/roles
while read -r unit role; do
  case $role in map-new|nolib) continue ;; esac
  wait_map "$(pid_of "$unit")" || { echo "setup: $unit did not load the library" >&2; exit 1; }
done < .lm-state/roles

# The upgrade: write the new file and rename it over the old one.
mv -f .lm-state/libssl.new "$LIB"

# One service is (re)started after the upgrade and maps the new file.
while read -r unit role; do
  [ "$role" = map-new ] || continue
  bin/systemctl start "$unit"
  wait_map "$(pid_of "$unit")" || { echo "setup: $unit did not load the library" >&2; exit 1; }
done < .lm-state/roles

# Remember every unit's PID, so the validator can tell who was restarted.
: > .lm-state/pids
while read -r unit role; do
  echo "$unit $role $(pid_of "$unit")" >> .lm-state/pids
done < .lm-state/roles

cat > TICKET.md <<'EOF'
# Security update: libssl3

CVE patch for libssl3 was installed on app-03 an hour ago
(usr/lib/x86_64-linux-gnu/libssl.so.3). The package does not restart anything.

Find the services that are still running with the OLD libssl in memory and
restart those, and only those: restarting the rest means a needless blip.

Write the names of the units that needed a restart, one per line
(e.g. api.service), to needs-restart.txt.
EOF
