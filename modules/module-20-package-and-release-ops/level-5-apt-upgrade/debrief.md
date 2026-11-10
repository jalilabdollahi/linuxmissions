# What Upgrade Keeps Back

## Why it works
`apt-get upgrade` is the careful mode: it only upgrades packages whose new version can be
installed **without installing a new package or removing an installed one**. Anything
that would need that is left alone and printed under "The following packages have been kept
back". `-s` makes apt print the whole plan and change nothing, so you can read it first.
`full-upgrade` (`dist-upgrade`) does the extra work: new dependencies come in, conflicting
packages go out.

## Common mistakes
- Counting "NOT upgraded" in the summary line: that number also includes held packages
  and things already at the newest version.
- Running `apt upgrade` for real to "see what happens". The simulation shows the same plan.
- Copying the heading or the whole paragraph; the file should hold names only.

## Next step
`apt-get -s full-upgrade | grep -E '^(Inst|Remv)'` shows exactly which packages would be
added or removed, which is what the change ticket should say about each kept-back package.
