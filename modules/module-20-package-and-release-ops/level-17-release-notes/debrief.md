# Release Notes for v2.4.0

## Why it works
Release notes are a filter over history: a range (between two tags), a set of commit types, and a few
exceptions. The awk range pattern `/start/ {on=1; next} /end/ {on=0} on` turns the tag markers into an on/off
switch; Conventional Commit prefixes make the sections a matter of one regex each (`!` before the colon
means breaking). A revert is two commits that cancel out, so both have to disappear: extract the reverted
subject from the revert line and drop everything that contains it (`grep -vF -f`).

## Common mistakes
- Including commits after v2.4.0 or before v2.3.0 because the whole file was processed.
- Listing the reverted fix and its `Revert "..."` line, or only dropping one of them.
- Putting a `feat!:` commit under both Features and Breaking, or keeping the `type(scope):` prefix.
- Using grep without `-F` for subjects: parentheses and dots are regex characters.

## Next step
With git available, `git log v2.3.0..v2.4.0 --oneline --no-merges` produces this range directly, and
`git log --grep='^Revert'` finds the reverts.
