# Six Teams, Six Doors to Root

## Why it works
A sudo rule lets a user run one command as root, so the question is what else that command can do.
Editors and pagers (`vim`, `less`) start a shell on request, `find` and `tar` run other programs from their
options, and in sudoers a `*` matches anything, including spaces and further options, so `restart app*` also
allows `restart app --now evil`. A script the user can edit is the same as no restriction, because the user
decides what runs as root. The safe forms give no freedom: `sudoedit FILE` edits a temporary copy as the user and
copies it back, exact argument lists allow exactly one command line, and a root-owned wrapper does its fixed job.
Files with a dot in their name (like `99-contractor.disabled`) are ignored by sudo, so they are not live rules.

## Common mistakes
- Flagging every `NOPASSWD` rule: a password prompt is not the problem, the command is.
- Replacing a wildcard with another wildcard, or deleting the rule and removing the team's ability to work.
- Pointing a rule at a wrapper that is group-writable (check the listing, not just the owner).
- Editing sudoers files without `visudo -cf`: a syntax error can lock everybody out of sudo.

## Next step
`sudo -l -U USER` lists what a user may run. GTFOBins (gtfobins.github.io) is the reference for which
binaries can escape; `sudoers(5)` explains `NOEXEC` and `sudoedit` restrictions.
