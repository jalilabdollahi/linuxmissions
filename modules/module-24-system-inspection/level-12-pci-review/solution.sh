#!/bin/bash
# Each device is a paragraph: a slot line, then indented detail lines.
awk -v RS= -F'\n' '
  {
    head = $1; drv = 0; mod = "-"
    for (i = 2; i <= NF; i++) {
      if ($i ~ /Kernel driver in use:/) drv = 1
      if ($i ~ /Kernel modules:/) { m = $i; sub(/.*Kernel modules: */, "", m); sub(/[ ,].*/, "", m); mod = m }
    }
    if (match(head, /\[0[12][0-9a-f][0-9a-f]\]:/) && !drv) {
      slot = head; sub(/ .*/, "", slot)
      s = head; sub(/\]: .*/, "", s)                       # keep it simple: take the last [xxxx:xxxx]
      id = head; while (match(id, /\[[0-9a-f]{4}:[0-9a-f]{4}\]/)) { last = substr(id, RSTART, RLENGTH); id = substr(id, RSTART + RLENGTH) }
      print slot, last, mod
    }
  }' capture/lspci.txt > unbound.txt
cat unbound.txt
