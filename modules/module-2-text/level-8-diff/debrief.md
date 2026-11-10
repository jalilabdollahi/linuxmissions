# Spot the Difference

## Why it works
`diff -u old new` prints only the changed lines with a few lines of context
around each change, grouped into hunks that start with `@@`. That context lets
`patch` find the right place even if the target file has shifted a little, which
is why unified diffs are the format of code review, `git diff` and mailing-list
patches. Your `changes.diff` turns any copy of v1.conf into v2.conf with
`patch v1.conf < changes.diff`.

## Common mistakes
- Plain `diff` (no `-u`) uses the old `<` / `>` format: hard to review, and fragile to apply.
- Swapping the files (`diff -u v2.conf v1.conf`) produces the reverse patch,
  which undoes the release instead of applying it.
- Reading diff's exit status 1 as an error: it just means "the files differ"
  (0 = identical, 2 = trouble).

## Learn next
`patch -R` reverses a patch (rollback), `diff -ru dir1 dir2` compares whole
directory trees, and `diff -y` (or `sdiff`) shows two files side by side.
