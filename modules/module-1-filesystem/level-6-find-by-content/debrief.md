# The Password Leak

## What you practiced
- `grep -r` searches recursively through all files in a directory
- `-l` prints only filenames, not matching lines (useful for audits)
- `-n` adds line numbers; `-i` makes the search case-insensitive

## Security note
Never hardcode passwords in config files. Use environment variables or a secrets manager (Vault, AWS Secrets Manager, etc.).

## Commands to remember
```bash
grep -r "TODO" .                  # find all TODOs
grep -rl "password" /etc          # which files mention password
grep -rn "error" logs/            # with line numbers
grep -ri "secret" . --include="*.conf"  # restrict to .conf files
```
