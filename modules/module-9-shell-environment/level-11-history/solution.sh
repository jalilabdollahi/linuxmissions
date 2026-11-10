#!/bin/bash
# A readable timeline: "YYYY-MM-DD HH:MM:SS  command" in UTC.
awk '/^#[0-9]+$/ { t = substr($0, 2); next } { print t, $0 }' home/deploy/.bash_history |
  while read -r t cmd; do
    printf '%s  %s\n' "$(date -u -d "@$t" '+%F %T' 2>/dev/null || date -u -r "$t" '+%F %T')" "$cmd"
  done > timeline.txt
day="$(sed -n 's/^Date: *//p' INCIDENT.txt)"
grep "^$day 02:[12]" timeline.txt
line="$(grep "^$day 02:[12]" timeline.txt | grep -e '-delete')"
echo "$line" | cut -c1-19 > when.txt
echo "$line" | cut -c22- > culprit.txt

cat >> home/deploy/.bashrc <<'EOF'

# keep a long, timestamped, shared history (INC-5521)
HISTSIZE=100000
HISTFILESIZE=100000
HISTTIMEFORMAT='%F %T '
HISTCONTROL=ignoredups
shopt -s histappend
EOF
