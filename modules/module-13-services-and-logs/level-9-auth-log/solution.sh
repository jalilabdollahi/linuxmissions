#!/bin/bash
grep -c 'Failed password' var/log/auth.log
grep 'Accepted' var/log/auth.log
# Walk the log in time order: add up failures per IP (a "message repeated N
# times" line is N failures); at each Accepted, check that IP's count so far.
awk '/sshd\[/ && /Failed password for/ {
       ip = $0; sub(/.* from /, "", ip); sub(/ .*/, "", ip)
       n = ($6 == "message" && $7 == "repeated") ? $8 : 1
       fails[ip] += n
     }
     /sshd\[/ && /Accepted / {
       ip = $0; sub(/.* from /, "", ip); sub(/ .*/, "", ip)
       user = $0; sub(/.*Accepted [a-z]+ for /, "", user); sub(/ .*/, "", user)
       if (fails[ip] >= 5) print ip, user
     }' var/log/auth.log | sort -u > compromised.txt
cat compromised.txt
