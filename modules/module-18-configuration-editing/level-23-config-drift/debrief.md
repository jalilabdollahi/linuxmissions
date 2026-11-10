# A Year of Hand Edits

## Why it works
Drift review is three questions: what differs in content (`diff -r`), what exists on only one side
(`diff -rq` says "Only in"), and what differs without any visible change in the content, such as permissions.
That last kind needs a metadata comparison (`find -printf '%m'`, `rsync -n -i`, `ls -l`), because a content diff
is silent. Restoring with `cp -p` brings the golden mode along; plain `cp` onto an existing file keeps the old mode.
An allowed override that sits inside a file that also drifted elsewhere cannot be fixed by copying: golden's
content with the one allowed line put back is the merge.

## Common mistakes
- Trusting `diff -r` alone: the mode-only drift stays invisible.
- Copying golden over chrony.conf and silently deleting the approved local override.
- Deleting unknown files from live instead of quarantining them: someone may still need to look at them.

## Next step
`rsync -rcni --delete golden/etc/ live/etc/` prints every difference (including mode and extra files) as a dry
run, and `aide` or `etckeeper` do this kind of audit continuously on real fleets.
