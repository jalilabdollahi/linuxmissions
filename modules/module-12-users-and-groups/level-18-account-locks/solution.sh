#!/bin/bash
# For each person on the ticket: match the email in the comment's 4th part, or the exact full
# name in its 1st part, then lock and expire that account. The 'deploy' comment only
# mentions an address inside free text, so it matches neither.
grep '^  - ' TICKET.md | while IFS= read -r l; do
  name=${l#  - }; name=${name%% <*}; name=${name%% (email:*}
  email=$(grep -o '[a-z.-]*@corp\.example' <<< "$l")
  user=$(awk -F: -v e="$email" -v n="$name" '{ split($5, g, ","); if (g[1] == n || g[4] == e) print $1 }' etc/passwd)
  echo "$name -> $user"
  bin/usermod -L -e 1 "$user"
done
