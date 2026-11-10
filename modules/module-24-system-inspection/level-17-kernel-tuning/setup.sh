#!/bin/bash
# Nothing to build but the paperwork: the vendor's requirement sheet and a sysctl.d
# directory with an unrelated existing file. The answer depends on THIS machine's
# live /proc/sys values, which the validator reads at check time.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p sysctl.d .lm-state
cat > sysctl.d/10-site.conf <<'T'
# site defaults (managed by config management, do not touch)
kernel.panic = 10
net.ipv4.tcp_syncookies = 1
T
cat > vendor-requirements.txt <<'T'
SearchCo Cluster 8 - kernel requirements (per node)

  vm.max_map_count                 >= 262144
  vm.swappiness                    =  1
  fs.file-max                      >= 2097152
  net.core.somaxconn               >= 4096
  net.ipv4.ip_local_port_range     first (low) port = 1024
T
cat > TICKET.md <<'T'
# search-07: prepare kernel settings for SearchCo

Read vendor-requirements.txt. Put the settings that THIS machine does not
meet yet into sysctl.d/90-search.conf (sysctl.d syntax, `key = value`).
Do not list settings that already comply, and never lower a value that is
already above the required minimum. (The file is only prepared here; nobody
applies it on this training machine.)
T
echo "ready" > .lm-state/ready
