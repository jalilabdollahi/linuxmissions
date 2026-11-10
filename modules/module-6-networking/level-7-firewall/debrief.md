# Open Sesame

## Why it works
iptables checks the rules of a chain in order and stops at the first one that
matches with a terminating target (ACCEPT, DROP, REJECT). The packet from the
office to 8443 matched `--dports 8000:8999 -j DROP` first, so the more
specific ACCEPT rule underneath was never reached. Moving the ACCEPT above the
range rule lets office traffic through, while everyone else still falls
through to the DROP, and the policy still catches whatever no rule mentions.

## Common mistakes
- Deleting the DROP rule: the office gets in, but so does every 10.20.x.x host
  through the "internal networks" rule, to the whole dev range. Changing the
  policy to ACCEPT is worse: everything is open to the internet.
- Appending another ACCEPT at the bottom with `iptables -A`: appended rules go
  *after* the DROP and never match. Specific exceptions go first (`-I`).

## Learn next
`iptables -L INPUT -n -v --line-numbers` shows packet counters per rule, which
is the quickest way to see which rule is eating traffic. Save and load whole
rulesets atomically with `iptables-save > file` and `iptables-restore < file`
(`iptables-restore --test` checks a file without applying it). On newer
systems the same ideas apply in `nft list ruleset`.
