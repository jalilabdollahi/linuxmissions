#!/bin/bash
# bastion-01's login banner is built from etc/update-motd.d (run by
# bin/render-motd, a stand-in for pam_motd). 20-maintenance is stale and still
# executable; there is no disk script. The disk percentage the fake bin/df
# reports is random per run. Traps: 50-disk.sh (a dot: run-parts skips it),
# a name that sorts in the wrong place, forgetting chmod +x.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")"
mkdir -p bin etc/update-motd.d .lm-state
cp "$M/render-motd" "$M/df" bin/
chmod +x bin/render-motd bin/df
echo $((23 + RANDOM % 60)) > .lm-state/usedpct
echo bastion-01 > etc/hostname

cat > etc/update-motd.d/00-header <<'LMEND'
#!/bin/sh
printf '=== bastion-01 (Ubuntu 24.04.2 LTS) ===\n'
LMEND
cat > etc/update-motd.d/10-sysinfo <<'LMEND'
#!/bin/sh
printf 'Load average: 0.12, 0.08, 0.05 | Users logged in: 3\n'
LMEND
cat > etc/update-motd.d/20-maintenance <<'LMEND'
#!/bin/sh
printf 'NOTICE: database failover 2026-10-28 22:00-23:00 UTC, expect dropped connections\n'
LMEND
cat > etc/update-motd.d/90-footer <<'LMEND'
#!/bin/sh
printf 'Access is logged. Report problems to #infra-oncall.\n'
LMEND
cat > etc/update-motd.d/README <<'LMEND'
Scripts here run at login, in name order, and print the message of the day.
Only executable files named with letters, digits, _ and - are used.
LMEND
chmod 755 etc/update-motd.d/00-header etc/update-motd.d/10-sysinfo etc/update-motd.d/20-maintenance etc/update-motd.d/90-footer
chmod 644 etc/update-motd.d/README

cat > TICKET.md <<'LMEND'
# INFRA-3340: bastion-01 login banner

1. The maintenance notice (20-maintenance) is about a window that ended
   weeks ago. Keep the script (we reuse it for the next window) but it must
   stop appearing at login.
2. The on-call runbook wants the root disk use in the banner, between the
   system info and the footer, as one line:

       Disk usage (/): NN%

   NN is the percentage df reports for /. In this sandbox df is bin/df.
3. See what users see with:  bin/render-motd
LMEND
( cd etc/update-motd.d && cksum 00-header 10-sysinfo 20-maintenance 90-footer ) > .lm-state/sums
