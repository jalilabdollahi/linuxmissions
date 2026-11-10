# Half a Vendor Patch

## Why it works
A patch is a list of hunks, each with a few lines of unchanged context. `patch` finds
the place by matching the context, tolerating an offset (our extra lines) and a little
fuzz, but when the lines right next to the change differ (we had edited
`health_check_interval`), it refuses the hunk and writes it to `proxy.conf.rej`
instead of guessing. `--dry-run` shows this in advance. The rest is a three-way merge
done by you: vendor change plus local edits, then cleaning up `.rej` and `.orig`.

## Common mistakes
- Forgetting `-p1` and patching a new `a/proxy.conf`, or giving `-p0` for a patch with `a/` `b/` prefixes.
- Copying the vendor's whole file over ours: all the local tuning is gone.
- Leaving `.rej` / `.orig` files that later tools may pick up as config.

## Next step
`patch -R` reverses a patch, `diff -u old new > fix.patch` makes one, and `git apply --3way`
merges instead of rejecting when the file is in a repository.
