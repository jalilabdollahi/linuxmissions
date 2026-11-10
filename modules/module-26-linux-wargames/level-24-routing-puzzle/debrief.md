## What you did

You read the routing decision the way the kernel makes it: rules by priority, each pointing at a table, a failed lookup falling through to the next rule, and inside a table the longest prefix first and the lowest metric second. A stale `priority 50` rule overrode the backup rule for one host, the backup table had no DC routes, the `dc` table (consulted before `main`) was missing the storage /24 that only existed in `main`, and two default routes with equal metric made the uplink a coin toss.

## Common mistakes

- Adding the /16 to the backup table and forgetting that the storage /24 needs its own gateway: the /24 would be ignored.
- Fixing a tie by adding a third route instead of changing the metric or removing the wrong default.
- Testing only the host from the ticket: other sources in the same subnet may hit different rules.

## Next

`ip rule add from X lookup T priority N` and `ip route get DST from SRC iif DEV` are the everyday tools for policy routing; `ip -6` works the same way, and `ip route show cache` was removed from modern kernels.
