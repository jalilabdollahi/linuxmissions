# Start Order

## Why it works
systemd keeps two independent ideas apart. `Wants=` and `Requires=` say
which units get pulled in, and what happens to this unit when the other one
stops or fails. `After=` and `Before=` say only in which order the jobs run.
`Requires=` without `After=` still starts both at the same time, which is
why app raced ahead of db-proxy. The fix needs both, in app's unit:
`Requires=db-proxy.service` for "stop me when it stops" and
`After=db-proxy.service` for "start me later". db-proxy also had
`After=app.service`: with that, each unit waits for the other, an ordering
cycle, and systemd breaks it by dropping one of the start jobs.

## Common mistakes
- Adding only `Requires=` (or keeping `Wants=`): the start order does not change.
- Adding `After=db-proxy.service` to app and leaving `After=app.service` in
  db-proxy.
- Putting the dependency on the wrong side: `Requires=app.service` in
  db-proxy stops the proxy whenever the app stops.
- Using `BindsTo=` / `PartOf=` and expecting ordering: they do not order
  either.

## Next step
`systemctl list-dependencies UNIT` and `systemd-analyze critical-chain` show
what a unit waits for. Real startup readiness needs `Type=notify`: `After=`
only waits until the other service has been started.
