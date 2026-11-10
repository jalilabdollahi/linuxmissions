# Exactly 3.1.4

## Why it works
`apt install fluxd` takes the **candidate**, the newest version. To get an older one you
say `fluxd=3.1.4-1`. That release depends on `libflux1 (<< 1.5)`, but 1.5.0 was already
installed, and apt does not downgrade an installed package on its own to satisfy a new one.
So the library is named in the same command, `libflux1=1.4.2-1`, and apt plans both together
(it lists the downgrade under "will be DOWNGRADED" before it asks).

## Common mistakes
- `apt install fluxd=3.1.4` without the revision (`-1`): works only if exactly one version
  starts that way; copy the string from `apt-cache madison`.
- Forcing it with `dpkg -i` and `--force-depends`: leaves a broken system (`apt-get check`
  reports it).
- In a script, `-y` refuses a downgrade unless you also add `--allow-downgrades`.

## Next step
`apt-mark hold fluxd` (module 20, level 9) stops the next `apt upgrade` from replacing the
version you picked, and `apt-get install --reinstall` puts back damaged files.
