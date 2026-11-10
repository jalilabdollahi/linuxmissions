#!/bin/bash
# Join the listing with the old and new account files by NAME: old numeric ID ->
# old name -> does the name exist on the new server?
awk '
  FILENAME == "old/etc/passwd" { split($0, a, ":"); ou[a[3]] = a[1]; next }
  FILENAME == "old/etc/group"  { split($0, a, ":"); og[a[3]] = a[1]; next }
  FILENAME == "etc/passwd"     { split($0, a, ":"); nu[a[1]] = 1; next }
  FILENAME == "etc/group"      { split($0, a, ":"); ng[a[1]] = 1; next }
  {
    path = $0; for (i = 1; i <= 7; i++) sub(/^[^ ]+ +/, "", path)
    u = ou[$3]; g = og[$4]
    if (!(u in nu)) seen["user " u] = 1
    if (!(g in ng)) seen["group " g] = 1
    spec = ""
    if (u in nu && g in ng) spec = u ":" g
    else if (u in nu) spec = u
    else if (g in ng) spec = ":" g
    q = path; gsub(/\047/, "\047\\\047\047", q)
    if (spec != "") printf "chown %s \047%s\047\n", spec, q > "chown-plan.sh"
  }
  END { for (k in seen) print k > "unmapped.txt" }
' old/etc/passwd old/etc/group etc/passwd etc/group restore-listing.txt
cat chown-plan.sh unmapped.txt
