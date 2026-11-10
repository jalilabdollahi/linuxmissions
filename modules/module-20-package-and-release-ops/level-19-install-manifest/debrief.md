# What Did the Hotfix Change?

## Why it works
A manifest is a list of facts about every file in a release: its permissions, a checksum of its content
and its path. Generating the same list from the deployed tree and comparing the two by path answers
"what changed" without trusting timestamps (which a hotfix, a copy or `touch` can change freely). Putting the
path last and reading with `IFS= read -r` keeps names with spaces whole; keying an awk array by the path
gives a three-way comparison (modified, missing, extra) in one pass.

## Common mistakes
- Comparing only hashes: a `chmod 777` leaves the content hash unchanged, but it is still a deviation.
- Letting spaces split the path (unquoted `$p`, `for f in $(find ...)`).
- Hashing the file with `sha256sum FILE` and cutting wrongly, or leaving a `./` prefix on one side only.
- Sorting with different locales when producing MANIFEST.

## Next step
`sha256sum -c MANIFEST.sha` verifies content only; `find -newer`, `diff -rq release deployed` and `rsync -ncai release/ deployed/`
give a quick differences list, and `stat -c '%a %U:%G %n'` adds the owner to a manifest.
