# Can You Hear Me?

## Why it works
ping's exit status is the machine-readable answer: 0 when at least one reply
came back, 1 when none did, 2 for errors such as a name that does not resolve.
`if ./ping -c 1 -W 1 "$host" >/dev/null 2>&1` tests exactly that, without
parsing the text. `-c 1` makes ping stop after one packet and `-W 1` caps the
wait, so one dead host costs a second instead of hanging the loop.

## Common mistakes
- Forgetting `-c`: real ping never stops on its own, so the loop sits on the
  first host forever.
- Grepping the output for "bytes from": it works until the output format or
  language changes. The exit status is the stable interface.
- Remember that a ping failure doesn't always mean the host is down: firewalls
  often drop ICMP while the services still work.

## Learn next
`ping -c 3 -i 0.2 -q HOST` prints only the summary line, handy for packet loss
numbers. To check a TCP service instead of ICMP, try `nc -z -w 2 HOST 22` or
`curl -sS -o /dev/null -w '%{http_code}' http://HOST/`.
