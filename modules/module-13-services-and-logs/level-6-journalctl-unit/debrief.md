# One Unit, One Window

## Why it works
The journal stores *who* logged each entry as fields, not as text:
- `_SYSTEMD_UNIT=payment.service` on everything the unit's processes wrote. That includes the
  `payment-migrate` step from `ExecStartPre=`, which logs under a different identifier.
- `UNIT=payment.service` on systemd's own messages about the unit ("Stopping ...",
  "Started ...", "Consumed 3min CPU time").

`-u payment.service` matches both, and nothing else. `payment@eu.service` is an
*instance* of a template (`payment@.service`), a different unit, and `payment-sync`
is a different unit too. `--since/--until` cut by the entry's timestamp, and `-o cat`
prints only `MESSAGE`.

## Common mistakes
- `journalctl | grep payment`: it catches the sync job, the EU instance and every line that
  merely mentions payment.service.
- `-t payment-api` (filtering by identifier): it misses the migration step and systemd's lines.
- A window without a date. That works here because it is the same day, but `"2026-11-10 01:31"`
  is unambiguous at any time.

## Next step
`journalctl -u 'payment@*'` matches every instance of the template. `-o json-pretty`
shows the `_SYSTEMD_UNIT`, `UNIT` and `SYSLOG_IDENTIFIER` fields of an entry, and
`journalctl -F _SYSTEMD_UNIT` lists the values that occur in the journal.
