#!/bin/bash
# Only paperwork: an empty inspect.sh stub and the report format. The validator runs the
# player's script against the live machine (and against listeners it starts itself).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > inspect.sh <<'T'
#!/bin/bash
# inspect.sh - print the JSON facts report described in TICKET.md
T
chmod +x inspect.sh
cat > TICKET.md <<'T'
# Fleet inventory: one script for every host

Write inspect.sh. It must run on any Linux host, as a normal user, and print
ONE JSON object to stdout (nothing else on stdout) with exactly these keys:

  hostname         string   the kernel's host name
  kernel           string   the kernel release
  arch             string   the machine hardware name
  os_id            string   ID from /etc/os-release
  os_version       string   VERSION_ID from /etc/os-release (a string, even for "24.04" or "12")
  cpus             number   number of CPUs available
  mem_total_mib    number   MemTotal in MiB, rounded down
  root_use_pct     number   use percentage of the filesystem mounted on / (as `df -P` shows it, without the %)
  uptime_seconds   number   seconds since boot, as an integer
  listening_ports  array    TCP ports with a listener owned by your user, as numbers, ascending, each once

Numbers must be JSON numbers, not strings; with no listener the array is [].
The script must read the machine each time it runs: nothing may be typed in.
T
