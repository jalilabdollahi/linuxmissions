# Why Not The New nginx

## Why it works
apt gives every available version a **priority** and installs the highest one; newness only
breaks ties. `apt-cache policy nginx` prints the table: the version with the largest number
is the Candidate. The numbers come from `/etc/apt/preferences.d/*.pref` (and
`/etc/apt/preferences`). Here the file named `10-...` pinned the old mirror at 900 and the
file named `99-...` pinned the new archive at only 600, so the old build won. The file name
only controls the order apt reads them in, not who wins.

## Common mistakes
- Assuming `99-` means "applied last, so it wins". For pins the highest priority wins.
- Trusting a `.bak` or `.disabled` file: apt ignores names with other extensions.
- Reading only the Candidate line and not the version table with the priorities.

## Next step
`apt-cache policy` for a single package shows exactly the table apt used. `apt install -t
SUITE package` overrides priorities for one command, and a pin of 1001 even forces
downgrades.
