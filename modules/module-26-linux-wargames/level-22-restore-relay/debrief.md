## What you did

You verified the archives first, then rebuilt the share by extracting the chain oldest to newest with `--listed-incremental=/dev/null`, which tells GNU tar to treat each archive as an incremental and remove files that were deleted since the previous one. The damaged Tuesday archive was replaced by its offsite copy, identified by its time and by comparing it with the other archives. Wednesday's archive, with the encrypted files, never went into the chain.

## Common mistakes

- Extracting with plain `tar -x`: files deleted on Monday and Tuesday come back.
- Applying the chain out of order, or including Wednesday's incremental.
- Trusting a file name: the offsite names are hashes, the dates are in the file times and contents.

## Next

`tar --list --listed-incremental=/dev/null -vf archive` shows what an incremental recorded, including `D` directory entries; `tar --compare` and `sha256sum` check a restore against a known state.
