# Error Extraction

## What you practiced
- `grep -E` enables extended regex (ERE) — allows `|`, `+`, `?`, `()`
- `-i` makes matching case-insensitive
- `-v` inverts the match (lines that do NOT match)
- `-c` counts matching lines instead of printing them

## Commands to remember
```bash
grep "ERROR" file.log                    # literal match
grep -E "ERROR|WARN|FATAL" file.log      # multiple patterns
grep -v "INFO" file.log                  # exclude INFO lines
grep -c "ERROR" file.log                 # count matching lines
grep -n "FATAL" file.log                 # show line numbers
grep -A 3 "ERROR" file.log              # show 3 lines after each match
```
