#!/bin/bash
export PATH="$PWD/bin:$PATH"
grep -E 'Accepted|Failed' var/log/auth.log | tail -n 12
# the attacker's session: the first successful login after the brute force, and its key
ip=$(grep 'Accepted password' var/log/auth.log | awk '{for (i = 1; i <= NF; i++) if ($i == "from") print $(i + 1)}' | tail -1)
fp=$(grep "Accepted publickey.* from $ip " var/log/auth.log | awk '{print $NF}' | tail -1)
printf '%s\n%s\n' "$ip" "$fp" > iocs.txt
ssh-keygen -lf home/deploy/.ssh/authorized_keys
# remove the key whose fingerprint is the attacker's
while read -r line; do
  [ "$(echo "$line" | ssh-keygen -lf - | awk '{print $2}')" = "$fp" ] || echo "$line"
done < home/deploy/.ssh/authorized_keys > ak.new && cat ak.new > home/deploy/.ssh/authorized_keys && rm ak.new
crontab -l | grep -v 'base64 -d' | crontab -
sed -i "/\.sysd\/sw/d" home/deploy/.bashrc
find home -perm -4000
rm -f home/deploy/.cache/.sysd/sh
