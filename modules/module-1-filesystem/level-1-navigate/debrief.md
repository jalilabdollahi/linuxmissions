# Lost in the Maze

## What you practiced
- **`find`** is your best friend for locating files in deep trees: `find / -name "filename"`
- Use `-type f` to restrict to files, `-type d` for directories
- `ls -la` shows hidden files; `tree` gives a visual hierarchy

## Key takeaway
When you don't know where a file is, `find` beats `ls` every time.
Add `-maxdepth N` to limit depth and speed up searches on large filesystems.

## Commands to remember
```bash
find /path -name "*.conf"          # find by name pattern
find /path -type f -name "secret*" # files only
find /path -newer /tmp/marker      # modified recently
```
