# Fail Loudly

## What you practiced
Strict mode catches problems early instead of letting a script limp along with bad state. Clear input validation makes failures understandable for the next person reading the logs.

## Commands to remember
```bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "SOURCE_FILE is required" >&2
  exit 1
fi
```
