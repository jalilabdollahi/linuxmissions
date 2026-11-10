#!/bin/bash
# -F finds hashed names, -R removes every entry for a name, then append the new keys.
ssh-keygen -F git.internal -f known_hosts
ssh-keygen -R git.internal -f known_hosts
ssh-keygen -R '[10.4.0.7]:2222' -f known_hosts
cat keyscan.txt >> known_hosts
ssh-keygen -F git.internal -f known_hosts
