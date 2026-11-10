# Finding What Should Never Have Been Committed

## Why it works
Credentials have recognisable shapes, so a handful of anchored regular expressions finds most of
them: `AKIA[0-9A-Z]{16}` for AWS key ids, `BEGIN .*PRIVATE KEY` for key blocks, a token prefix such
as `ghp_`, and `password` as a setting name. `grep -r` descends into hidden directories such as
`.git-old/`, but it cannot see inside compressed files, which is why old logs need `zgrep`.
Removing the documented placeholders (`AKIAIOSFODNN7EXAMPLE`) and non-values (`<...>`, `${...}`)
is what separates a useful report from noise nobody reads.

## Common mistakes
- `grep -ri password` buries the real findings in comments, `password_min_length` and docs.
- Forgetting case and spacing: `PASSWORD=` and `password = x` are the same leak as `password=x`.
- Deleting the secret and calling it done: a credential that was committed must also be revoked and rotated.

## Next step
Real scanners (`gitleaks`, `trufflehog`) also search git history, where a deleted secret still
lives. `git log -p -S'AKIA'` shows when a string was added or removed.
