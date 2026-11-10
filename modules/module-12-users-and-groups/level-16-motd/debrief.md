# Stale Login Banner

## Why it works
At login, PAM's `pam_motd` runs the scripts in `/etc/update-motd.d` in name order and
prints their output as the message of the day. It uses the rules of `run-parts`: a
file takes part only if it is **executable**, and (in the `--lsbsysinit` mode used
here) only if its name has nothing but letters, digits, `_` and `-`. So `chmod -x`
parks a script without deleting it, and the two-digit prefix (`50-`) puts the new
script between `10-` and `90-`. The script computes the number each time, which is
why the validator changed what `df` reports before checking again.

## Common mistakes
- `50-disk.sh`: the dot makes run-parts skip the file, silently. No error, no output.
- A one-digit prefix such as `5-disk`: names sort as text, so it comes after `10-sysinfo`, not before it. Two digits keep the order obvious.
- Forgetting `chmod +x` on the new file.

## Next step
`run-parts --test /etc/update-motd.d` lists what would run without running it, which
is the quickest way to find a script that is being skipped.
