# Reading the Quota Report

## Why it works
`repquota` prints, per user, block usage and limits, then file (inode) usage and limits, each with a grace column.
The flag pair after the name is block first, file second: `-+` means a file limit is exceeded and blocks are fine.
A grace time counts down from the moment the soft limit was crossed; when it reaches zero the report shows
`none` and the soft limit is enforced like a hard one. A user at the hard limit is blocked immediately.

`setquota` always takes all four limits, so changing one pair means passing the current value of the other pair.
Block limits are in 1 KiB units: 100 GiB is 104857600. A `0` means "no limit", so passing 0 for the inode limits
silently removes them.

## Common mistakes
- Splitting the line on whitespace and assuming fixed columns: a blank grace column moves everything left.
- Listing a user at the hard limit in both files.
- Setting block limits in GiB or MiB, or zeroing the inode limits.

## Next step
`setquota -p PROTOUSER user...` copies one user's limits to others, `setquota -t` sets grace periods, and
`quota -u USER` shows what a single user sees. Real quotas need `usrquota` in fstab and `quotacheck`/`quotaon`.
