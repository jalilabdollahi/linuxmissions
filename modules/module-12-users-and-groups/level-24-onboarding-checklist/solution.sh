#!/bin/bash
H=$(grep '^INITIAL_HASH=' TICKET.md | cut -d= -f2-)
# the automatic UID would be 1500 (reserved), so give the UIDs explicitly
bin/useradd -m -u 1600 -c 'Ana Ribeiro' -s /bin/bash -G engineers,docker -p "$H" ana
bin/useradd -m -u 1601 -c 'Cara Lindholm' -s /bin/bash -G engineers,docker -p "$H" cara
# ben exists: unlock, clear the expiry, give him a shell and the groups
bin/usermod -U -e '' -s /bin/bash -aG engineers,docker ben
# ben has no container ranges: the first free ID after every existing range
for kind in subuid subgid; do
  next=$(awk -F: '$2 + $3 > m { m = $2 + $3 } END { print m }' etc/$kind)
  if [ $kind = subuid ]; then bin/usermod -v $next-$((next + 65535)) ben; else bin/usermod -w $next-$((next + 65535)) ben; fi
done
# force a password change at first login
for u in ana ben cara; do bin/chage -d 0 $u; done
# sudo for the group
echo '%engineers ALL=(ALL:ALL) ALL' > etc/sudoers.d/engineers
chmod 0440 etc/sudoers.d/engineers
bin/visudo -c
