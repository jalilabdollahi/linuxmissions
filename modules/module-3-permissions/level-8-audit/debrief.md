# World Writable Files

## What you practiced
- `find -perm /o+w` finds files where "others" have write permission
- `chmod o-w` removes write from "others" without touching owner/group
- Combining `find -exec chmod` is a single-pass security fix

## Security context
World-writable files are a common finding in security audits. An attacker who can write to a config or script file could:
- Inject malicious code into startup scripts
- Alter application configuration
- Replace executables (if also executable)

## Commands to remember
```bash
find / -perm /o+w -type f 2>/dev/null       # system-wide audit
find /etc -perm /o+w 2>/dev/null            # check /etc
find . -perm /o+w -exec chmod o-w {} \;    # fix them all
chmod o-w file                              # fix one file
chmod 644 file                              # set explicitly
```
