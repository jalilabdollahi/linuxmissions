#!/bin/bash
# Move the office-only 8443 ACCEPT rule above the DROP for 8000-8999.
rule="$(grep -e '--dport 8443' firewall.rules)"
grep -v -e '--dport 8443' firewall.rules \
  | awk -v r="$rule" '/--dports 8000:8999/ { print r } { print }' > firewall.new
mv firewall.new firewall.rules
grep -n -e '^-A INPUT' firewall.rules
