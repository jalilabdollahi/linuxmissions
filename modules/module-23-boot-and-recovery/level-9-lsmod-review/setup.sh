#!/bin/bash
# Which Modules Went Missing? Two lsmod captures. Healthy has the whole md RAID
# 4/5/6 stack (raid456 on top, then async_*, xor, raid6_pq); the broken host has md_mod
# and libcrc32c but none of the rest, plus other noise (different order, sizes, counts).
# "Used by" lists the modules that depend ON this one, so the module to load is the
# missing one that no other missing module uses: raid456.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > healthy.lsmod <<'EOT'
Module                  Size  Used by
raid456               196608  1
async_raid6_recov      20480  1 raid456
async_memcpy           16384  2 raid456,async_raid6_recov
async_pq               16384  2 raid456,async_raid6_recov
async_xor              16384  3 async_pq,raid456,async_raid6_recov
xor                    24576  2 async_xor,raid456
raid6_pq              122880  3 async_pq,raid456,async_raid6_recov
libcrc32c              12288  2 xfs,raid456
md_mod                200704  1 raid456
xfs                  2113536  2
ext4                 1052672  1
mbcache                16384  1 ext4
jbd2                  176128  1 ext4
nvme                   57344  4
nvme_core             204800  5 nvme
e1000e                311296  0
ptp                    40960  1 e1000e
pps_core               24576  1 ptp
ahci                   49152  0
libahci                49152  1 ahci
crc32c_intel           12288  1
dm_mod                192512  0
EOT
cat > broken.lsmod <<'EOT'
Module                  Size  Used by
dm_mod                192512  0
uas                    32768  0
usb_storage            86016  1 uas
crc32c_intel           12288  1
libahci                49152  1 ahci
ahci                   49152  0
pps_core               24576  1 ptp
ptp                    40960  1 e1000e
e1000e                311296  0
nvme_core             204800  5 nvme
nvme                   57344  4
jbd2                  176128  1 ext4
mbcache                16384  1 ext4
ext4                 1052672  1
xfs                  2117632  2
md_mod                200704  0
libcrc32c              12288  1 xfs
EOT
cksum healthy.lsmod broken.lsmod > .lm-state/sums
