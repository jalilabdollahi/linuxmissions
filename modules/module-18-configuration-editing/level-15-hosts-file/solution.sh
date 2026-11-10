#!/bin/bash
# Two passes with awk. Pass 1 keeps the first IP of every name (the resolver's rule) and
# collects the names per address. Pass 2 rewrites the file: comments and blanks as they
# are, 10.9.* lines commented out, each address printed once at its first line.
awk '
NR == FNR {
  if ($0 ~ /^[[:space:]]*(#|$)/ || $1 ~ /^10\.9\./) next
  for (i = 2; i <= NF; i++)
    if (!($i in seen)) {
      seen[$i] = 1
      names[$1] = names[$1] " " $i
    }
  next
}
/^[[:space:]]*(#|$)/ { print; next }
$1 ~ /^10\.9\./ { print "# " $0; next }
!($1 in done) && names[$1] != "" { done[$1] = 1; print $1 names[$1] }
' etc/hosts etc/hosts > etc/hosts.new && mv etc/hosts.new etc/hosts
cat etc/hosts
