# Needle in a Haystack

## What you practiced
- `find` with `-name` does shell glob matching (not regex)
- `>` redirects stdout to a file (overwrites); `>>` appends
- Combining `find` output with redirection is a core shell pattern

## Commands to remember
```bash
find /path -name "*.py" > list.txt      # save results to file
find /path -name "*.py" | wc -l         # count matches
find /path -iname "*.PY"                # case-insensitive
find /path -name "*.py" -not -path "*/venv/*"  # exclude venv
```
