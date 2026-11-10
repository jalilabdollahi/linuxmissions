# Knock, Knock

## Why it works
A TCP connect has three outcomes, and each one points somewhere else:
- **accepted**: something listens; whether it works is the next question.
- **refused** (RST at once): the host is reachable but nothing listens on that
  port: the service is down or bound to another address.
- **timed out**: the SYN disappears: a firewall drops it, a route is missing,
  or the listener is so overloaded its queue is full.

`nc -z -w2` turns that into an exit status within 2 seconds. The status
backend shows why a port check is not a health check: it accepts the
connection and then waits for the client to speak first (like SMTP clients
waiting for a banner, but the other way round). `printf 'STATUS\n' | nc -q1`
sends the command and keeps listening briefly for the answer.

## Common mistakes
- `nc HOST PORT` with no input and no timeout: it sits there forever on a silent service.
- `nc -z` without `-w`: the filtered port takes the kernel's full SYN retry time (about two minutes).
- Counting "timed out" as open: no connection was ever made.

## Learn next
bash can do the same check without nc:
`timeout 2 bash -c '</dev/tcp/127.0.0.1/PORT' && echo open` (next level).
`nc -lv PORT` turns nc into a tiny server, handy to test firewalls from the
other side.
