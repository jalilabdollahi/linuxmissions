## What you did

You resolved the incident in the order that makes the fix stick. Restarting the shop first would have worked for seconds: a cron job installed by a deploy made with a leaked key added a chunk to the volume every minute (from two places: the user crontab and `etc/cron.d`), the volume filled, and the app exited on a full disk. So you removed the job everywhere while keeping the legitimate ones (including the other every-minute job), freed space by retention (cache first, old orders too, but never `audit/`, which held the evidence), revoked the key by body wherever it was listed, restarted the service and recorded fingerprint, deploy ID, first bad run and the cause chain for the postmortem.

## Common mistakes

- Cleaning the disk or restarting the app while the job is still scheduled.
- `rm -rf var/cache/shop/*`: it deletes the audit evidence.
- `crontab -r`: it removes the nightly backup and the heartbeat as well.
- Removing keys by comment instead of by key body: the same key was listed under two different comments.

## Next

`cron-run`/`systemctl list-timers` style checks, `ssh-keygen -lf` for fingerprints, `last`/`journalctl` to see what a key was used for, and writing a blameless postmortem with a timeline, the cause chain and the action items.
