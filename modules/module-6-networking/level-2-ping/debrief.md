# Can You Hear Me?

## What you practiced
Ping-like checks are really about success and failure codes. In scripts, the exit status is often more important than the printed output.

## Commands to remember
```bash
ping -c1 host
if ping -c1 "$host" >/dev/null 2>&1; then
  echo "$host"
fi
```
