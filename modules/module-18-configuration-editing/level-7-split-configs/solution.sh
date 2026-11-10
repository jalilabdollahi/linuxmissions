#!/bin/bash
# Count braces to find the end of each server block; name the file after its
# first server_name. Lines outside blocks that start with # form the header.
mkdir -p sites-available
awk '
  /^server[[:space:]]*\{/ { inblk = 1; depth = 0; buf = ""; name = "" }
  inblk {
    buf = buf $0 "\n"
    if (name == "" && $1 == "server_name") { name = $2; sub(/;$/, "", name) }
    line = $0; sub(/#.*/, "", line)
    depth += gsub(/\{/, "{", line) - gsub(/\}/, "}", line)
    if (depth == 0) {
      f = "sites-available/" name ".conf"
      printf "%s", buf > f
      close(f)
      inblk = 0
    }
    next
  }
  /^#/ { print > "sites-available/00-header.conf" }
' sites.conf
ls sites-available
