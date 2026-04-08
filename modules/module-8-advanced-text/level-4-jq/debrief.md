# JSON Surgeon

## What you practiced
Nested JSON becomes manageable once you can select fields and filter arrays. `jq` is the standard CLI tool for that style of work.

## Commands to remember
```bash
jq -r '.owner.email' data.json
jq -r '.services[] | select(.active) | .name' data.json
jq -r '[.services[] | select(.active) | .name] | join(",")' data.json
```
