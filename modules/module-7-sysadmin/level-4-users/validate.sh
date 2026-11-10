#!/bin/bash
SANDBOX="$1"
P="$SANDBOX/etc/passwd"
G="$SANDBOX/etc/group"

if [ ! -f "$P" ] || [ ! -f "$G" ]; then
  echo "❌ etc/passwd or etc/group is missing"
  exit 1
fi
if awk -F: 'NF != 7 { bad = 1 } END { exit !bad }' "$P"; then
  echo "❌ etc/passwd has a line without exactly 7 colon-separated fields"
  exit 1
fi
if awk -F: 'NF != 4 { bad = 1 } END { exit !bad }' "$G"; then
  echo "❌ etc/group has a line without exactly 4 colon-separated fields"
  exit 1
fi

field() { awk -F: -v u="$1" -v n="$2" '$1 == u { print $n; exit }' "$P"; }
# is USER listed as a member of GROUP?
member() { awk -F: -v g="$2" -v u="$1" '$1 == g { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] == u) f = 1 } END { exit !f }' "$G"; }

if ! grep -q '^dana:' "$P"; then
  echo "❌ there is no account named dana yet"
  exit 1
fi
if [ "$(grep -c '^dana:' "$P")" -ne 1 ]; then
  echo "❌ etc/passwd has more than one dana line"
  exit 1
fi
uid="$(field dana 3)"; gid="$(field dana 4)"
if [ "$(cut -d: -f3 "$P" | grep -cx "$uid")" -ne 1 ] || [ "$uid" -lt 1000 ]; then
  echo "❌ dana needs a unique regular-user UID (1000 or higher)"
  exit 1
fi
if [ "$(awk -F: -v g="$gid" '$3 == g { print $1; exit }' "$G")" != "dana" ]; then
  echo "❌ dana's primary group should be her own private group 'dana'"
  exit 1
fi
if [ "$(field dana 5 | cut -d, -f1)" != "Dana Kim" ]; then
  echo "❌ dana's full name (the comment/GECOS field) is not 'Dana Kim'"
  exit 1
fi
if [ "$(field dana 7)" != "/bin/bash" ]; then
  echo "❌ dana's login shell is $(field dana 7), not /bin/bash"
  exit 1
fi
if [ "$(field dana 6)" != "/home/dana" ]; then
  echo "❌ dana's home directory in etc/passwd is not /home/dana"
  exit 1
fi
if [ ! -d "$SANDBOX/home/dana" ] || [ ! -f "$SANDBOX/home/dana/.bashrc" ] || [ ! -f "$SANDBOX/home/dana/.profile" ]; then
  echo "❌ /home/dana was not created from /etc/skel (it should exist with .bashrc and .profile)"
  exit 1
fi
for g in dev docker; do
  if ! member dana "$g"; then
    echo "❌ dana is not in the $g group"
    exit 1
  fi
done
if member dana sudo || member dana adm; then
  echo "❌ dana should not get admin groups (sudo/adm)"
  exit 1
fi
for g in docker sudo dev adm; do
  if ! member sam "$g"; then
    echo "❌ sam is not in the $g group (he must keep his old groups and gain docker)"
    exit 1
  fi
done
for g in docker dev; do
  if ! member lee "$g"; then
    echo "❌ lee lost his membership of $g; leave other users alone"
    exit 1
  fi
done

echo "✅ dana is set up correctly and sam joined docker without losing his other groups"
exit 0
