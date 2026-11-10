#!/bin/bash
# Service accounts (UID 1-999 and nobody) with a login shell -> nologin; people whose
# shell is not in etc/shells and not a no-login shell -> /bin/bash. root and sync stay.
cut -d: -f1,3,7 etc/passwd
grep -v '^#' etc/shells
for u in $(awk -F: '$3 ~ /^[0-9]+$/ && $1 != "root" && $1 != "sync" && ($3 < 1000 || $3 > 59999) && $7 != "/usr/sbin/nologin" && $7 != "/bin/false" { print $1 }' etc/passwd); do
  bin/usermod -s /usr/sbin/nologin "$u"
done
for u in $(awk -F: 'NR == FNR { if ($0 !~ /^#/) ok[$0] = 1; next } $3 ~ /^[0-9]+$/ && $3 >= 1000 && $3 <= 59999 && !($7 in ok) && $7 != "/usr/sbin/nologin" && $7 != "/bin/false" { print $1 }' etc/shells etc/passwd); do
  bin/usermod -s /bin/bash "$u"
done
cut -d: -f1,3,7 etc/passwd
