# Who Are You, Really?

## Why it works
Anybody who controls an IP block can put any name in its PTR records, so a PTR
alone proves nothing. Forward-confirmed reverse DNS checks the round trip: IP
→ PTR name → A records → the same IP again. Only the owner of both the
reverse zone and the forward zone can make that loop close, which is why mail
servers use it. What passed: a name with several A records (one of them the IP is enough) and a
name that is a CNAME to the host with the address. What failed:
- no PTR at all,
- a PTR whose name points to a different address, one digit longer than the
  sender, which a substring match like `grep 192.0.2.4` would have let through,
- a PTR written as `mx.example` instead of `mx.example.` in the zone file. The
  server appended the zone's origin, so the record really says
  `mx.example.2.0.192.in-addr.arpa.`, which doesn't exist.

## Common mistakes
- Comparing with grep and unescaped dots, or matching a prefix of the address.
- "Fixing" the odd PTR in your head: the relay sees exactly what DNS says.

## Learn next
`dig -x IP +short` is the dig way to do a reverse lookup. Postfix enforces
this with `reject_unknown_client_hostname`; its milder sibling
`reject_unknown_reverse_client_hostname` only requires that a PTR exists.
