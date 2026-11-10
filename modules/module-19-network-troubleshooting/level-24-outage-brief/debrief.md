# Outage Brief

## Why it works
Four independent faults stacked on top of each other, and each one hid the
next:
1. **Proxy:** the standard template set `http_proxy` but `no_proxy` didn't
   cover `.corp.example`, so every backend call went to a proxy that can't
   reach the internal network and timed out. Timeouts tell you nothing
   about the backends, so this had to go first.
2. **Port:** CHG-7001 moved the payments listeners and published the new
   port as an SRV record; checkout still dialled 8080 (connection refused).
   The first failed call in the log came right after this change: the root
   cause. The other two changes only made it worse.
3. **Hosts pin:** an old `/etc/hosts` line kept one backend on its previous
   address after CHG-7002, which DNS (and `dig`) had already updated.
4. **Unhealthy backend:** it accepted connections and answered 503, so a
   port check (`nc -z`, `ss`) said "fine". Only an HTTP check shows it.

## Common mistakes
- Changing several things at once and not re-running the test: you can't
  tell which change fixed what, and the brief becomes guesswork.
- Fixing the port first: every call still times out at the proxy and it
  looks as if the port change did nothing.
- Counting every ERROR line: inventory failures are a different incident.
- Removing http_proxy entirely: the FX rates need the proxy.

## Learn next
`curl -v` shows "Uses proxy env variable" and the address it connects to;
`curl -w '%{remote_ip}:%{remote_port}'` prints where a request really went.
In a real brief, add detection time and a follow-up list (template
no_proxy, an SRV-aware client, health checks that use HTTP, not just TCP).
