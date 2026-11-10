#!/bin/bash
# Who Still Needs a Reboot? Ten hosts under fleet/. Traps: 6.8.0-9 vs 6.8.0-45 (text
# sort), cache-01 runs a custom kernel NEWER than anything installed (not a reboot
# case), db-02 has a removed ("rc") newer kernel, the meta-package and headers lines,
# and uname -a lines with a variable number of fields after the release.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p fleet .lm-state

host() {  # host NAME RUNNING UNAME_TAIL ; installed kernels on stdin as "state version"
  local h="$1" run="$2" tail="$3"
  mkdir -p "fleet/$h"
  printf 'Linux %s %s %s x86_64 x86_64 x86_64 GNU/Linux\n' "$h" "$run" "$tail" > "fleet/$h/uname.txt"
  {
    echo 'Desired=Unknown/Install/Remove/Purge/Hold'
    echo '| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend'
    echo '|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)'
    echo '||/ Name                                Version        Architecture Description'
    echo '+++-===================================-==============-============-=============================================='
    local newest=""
    while read -r st ver; do
      [ -n "$st" ] || continue
      printf '%-2s  %-35s %-14s amd64        Signed kernel image generic\n' "$st" "linux-image-$ver" "${ver%-generic}.${ver#*-}"
      printf 'ii  %-35s %-14s amd64        Linux kernel headers for %s\n' "linux-headers-$ver" "${ver%-generic}.${ver#*-}" "$ver"
    done
    printf 'ii  %-35s %-14s amd64        Generic Linux kernel image\n' "linux-image-generic" "6.8.0-31.31"
  } > "fleet/$h/kernels.txt"
}
T45='#45-Ubuntu SMP PREEMPT_DYNAMIC Fri Aug 30 12:02:04 UTC 2024'
T31='#31-Ubuntu SMP PREEMPT_DYNAMIC Fri Jul  5 16:59:26 UTC 2024'
T9='#9-Ubuntu SMP PREEMPT_DYNAMIC Mon Apr  8 08:10:02 UTC 2024'
T118='#128-Ubuntu SMP Fri Jul  5 09:28:59 UTC 2024'
T91='#101-Ubuntu SMP Tue Nov 14 13:30:08 UTC 2023'

host web-01 6.8.0-45-generic "$T45" <<'EOT'
ii 6.8.0-45-generic
EOT
host web-02 6.8.0-31-generic "$T31" <<'EOT'
ii 6.8.0-31-generic
ii 6.8.0-45-generic
EOT
host web-03 6.8.0-9-generic "$T9" <<'EOT'
ii 6.8.0-9-generic
ii 6.8.0-31-generic
EOT
host db-01 5.15.0-118-generic "$T118" <<'EOT'
ii 5.15.0-91-generic
ii 5.15.0-118-generic
ii 6.8.0-45-generic
EOT
host db-02 6.8.0-45-generic "$T45" <<'EOT'
ii 6.8.0-31-generic
ii 6.8.0-45-generic
rc 6.8.0-50-generic
EOT
host cache-01 6.9.3-fips1 '#1 SMP PREEMPT_DYNAMIC Tue Jun 11 08:12:31 UTC 2024' <<'EOT'
ii 6.8.0-45-generic
EOT
host app-1 6.8.0-45-generic "$T45" <<'EOT'
rc 5.15.0-91-generic
ii 6.8.0-31-generic
ii 6.8.0-45-generic
EOT
host app-2 6.8.0-31-generic "$T31" <<'EOT'
ii 6.8.0-9-generic
ii 6.8.0-31-generic
ii 6.8.0-45-generic
EOT
host bastion 5.15.0-91-generic "$T91" <<'EOT'
ii 5.15.0-91-generic
ii 5.15.0-118-generic
EOT
host mon-01 6.8.0-31-generic "$T31" <<'EOT'
ii 6.8.0-9-generic
ii 6.8.0-31-generic
EOT
cksum fleet/*/* > .lm-state/sums
