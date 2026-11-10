#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
inst=$(dpkg-query -W -f='${Version}' libxparse1)
zcat libxparse/changelog.Debian.gz | awk -v inst="$inst" '
  /^libxparse \(/ { n++; ver[n] = substr($2, 2, length($2) - 2) }
  /CVE-2026-1182([^0-9]|$)/ { if ($0 ~ /[Rr]evert/) kind[n] = "R"; else if ($0 ~ /[Ff]ix/) kind[n] = "F" }
  END {
    for (i = n; i >= 1; i--) {
      if (kind[i] == "F") { if (!first) first = ver[i]; st = 1 } else if (kind[i] == "R") st = 0
      if (ver[i] == inst) p = st ? "yes" : "no"
    }
    print "first_fixed=" first; print "patched=" p
  }' > cve.env
