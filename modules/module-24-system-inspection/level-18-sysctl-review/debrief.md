# Which File Wins?

## Why it works
`systemd-sysctl` does not read one file. It merges the `sysctl.d` directories
by file name: if `/etc` has a file of the same name as one in `/usr/lib`, the
`/usr/lib` one is ignored entirely (that is how admins override a packaged
file, and why its other keys vanish too). The surviving files are applied in
lexicographic name order, regardless of directory, and the last assignment of
a key wins. On Ubuntu `sysctl.conf` joins the order as `99-sysctl.conf`, so a
file named `99-zz-...` runs after it and can quietly undo it. That is
exactly what the compliance agent's hardening file did to `ip_forward`.

## Common mistakes
- Trusting `sysctl.conf` because it is the "main" file.
- Sorting names numerically: `9-legacy.conf` comes after `60-performance.conf`.
- Counting keys from a masked file, or listing `net/ipv4/ip_forward` and
  `net.ipv4.ip_forward` as two keys.

## Next step
`systemd-analyze cat-config sysctl.d/` prints the merged configuration in
order with the file names, and `sysctl --system` applies and logs each file.
