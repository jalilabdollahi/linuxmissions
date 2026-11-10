#!/bin/bash
# NAS Storage Bill: a 50,000-line listing of the NAS, made with
#   find /nas -printf '%p\t%u\t%s\t%TY-%Tm-%Td\n' > files.lst 2>&1
# so paths (with spaces) come first, sizes reach tens of GiB, and a few
# "Permission denied" errors ended up in the file. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  nu = split("amira bjorn carmen deepak elena farid gwen hiroshi ingrid jamal katya liam", user, " ")
  for (u = 1; u <= nu; u++) weight[u] = 0.3 + rand() * 2
  ndir = split("Projects|Photos 2023|Scans|Backups|Videos|Shared With Me|Old Laptop|Music|Documents|Tax Returns", dir, "|")
  next_err = 3000
  for (n = 1; n <= 50000; n++) {
    do { u = int(rand() * nu) + 1 } while (rand() * 2.3 > weight[u])
    d = dir[int(rand() * ndir) + 1]
    r = rand()
    if (r < 0.004)      { size = int((2 + rand() * 58) * 1073741824); name = "vm-disk-" int(rand() * 99) ".qcow2" }
    else if (r < 0.02)  { size = int((0.6 + rand() * 4) * 1073741824); name = "ubuntu-" (20 + int(rand() * 6)) ".04-desktop-amd64.iso" }
    else if (r < 0.12)  { size = int(rand() * 900 * 1048576); name = "clip " int(rand() * 9999) ".mp4" }
    else if (r < 0.50)  { size = int(rand() * 12 * 1048576); name = "IMG_" int(1000 + rand() * 8999) ".jpg" }
    else                { size = int(rand() * 400 * 1024); name = "notes " int(rand() * 999) ".txt" }
    y = 2019 + int(rand() * 8); m = 1 + int(rand() * 12); if (y == 2026 && m > 10) m = 10
    printf "/nas/home/%s/%s/%s\t%s\t%d\t%04d-%02d-%02d\n", user[u], d, name, user[u], size, y, m, 1 + int(rand() * 28)
    if (n == next_err) {
      printf "find: '\''/nas/home/%s/.Private'\'': Permission denied\n", user[int(rand() * nu) + 1]
      next_err += 4000 + int(rand() * 8000)
    }
  }
}' > files.lst

cksum < files.lst > .lm-state/files.sum
