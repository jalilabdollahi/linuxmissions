# Build the Scaffold

## What you practiced
- `mkdir -p` creates parent dirs automatically — no need to create each one step by step
- Brace expansion `{a,b,c}` saves keystrokes when creating related directories
- `tree` (if installed) gives a nice visual summary of any directory

## Commands to remember
```bash
mkdir -p /var/app/{logs,data,tmp}          # brace expansion
mkdir -p a/b/c/d                           # deep nesting in one shot
ls -R                                       # recursive listing
tree -L 2                                   # two levels deep (needs tree package)
```
