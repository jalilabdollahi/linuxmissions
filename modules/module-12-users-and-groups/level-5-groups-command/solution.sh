#!/bin/bash
# For each user: the groups the database gives them (bin/id -G) against the
# Groups: line of their running session. Anything the database has and the
# session lacks means a re-login is due.
cat etc/group
for f in sessions/*.status; do
  u=$(basename "$f" .status)
  want=$(bin/id -G "$u" | tr ' ' '\n' | sort)
  have=$(awk '/^Groups:/ { for (i = 2; i <= NF; i++) print $i }' "$f" | sort)
  [ -n "$(comm -23 <(echo "$want") <(echo "$have"))" ] && echo "$u"
done > relogin.txt
cat relogin.txt
