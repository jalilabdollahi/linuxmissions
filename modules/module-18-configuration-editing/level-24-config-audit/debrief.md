# Migration Aftermath

## Why it works
A checker that reports only the first error turns repair into a loop: run, read, fix, repeat. Each format has
its own failure mode: INI needs `key = value`, an env file forbids spaces around `=`, JSON rejects trailing commas
and (in most parsers) silently keeps the last of two equal keys, YAML forbids tabs and distinguishes `"6379"` from
`6379`, and hosts needs real IP addresses. Fixing the cause instead of deleting the setting matters, because the
checker may accept a missing optional key that the application then runs without. The last proof is behavioural: the
service has to answer with the version it should be running.

## Common mistakes
- Deleting a line to silence the checker: the config "passes" and the app runs with a default.
- Removing the wrong one of two duplicate JSON keys: the file is valid and the feature is switched off.
- Starting the app, then fixing a value: it keeps serving the old configuration until restarted.

## Next step
`python3 -m json.tool`, `yamllint` and `shellcheck` are quick per-format linters, and `diff` against the previous
version of each file (kept in version control) shows exactly what the migration changed.
