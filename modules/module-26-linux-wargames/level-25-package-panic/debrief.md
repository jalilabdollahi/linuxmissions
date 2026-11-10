## What you did

You treated `/var/lib/dpkg/status` as what it is, a database of paragraphs, and read it in awk's paragraph mode, anchoring on field names so the prose inside descriptions (which also mentions "Depends:") could not fool you. Version comparisons went to `dpkg --compare-versions`, because `1.2.10` is newer than `1.2.9`, an epoch (`1:0.9`) beats `1.0`, and `2.0~rc1` is older than `2.0`. The configure order is a topological sort of the Depends and Pre-Depends edges inside the broken set, which is exactly what `tsort` does.

## Common mistakes

- `sort -V` or string comparison on versions: wrong for epochs and tildes.
- `grep Depends` also matches description text; Pre-Depends are dependencies too.
- Listing a package on `hold` as broken: it is installed, just pinned.

## Next

`dpkg-query -W -f='${Package} ${db:Status-Abbrev}\n'` prints the same states the real tools use, `dpkg --audit` lists half-installed packages, and `dpkg --configure -a` is the real fix once the order is known.
