# One-Shot Task

## What you practiced
`at` is the tool for one-time scheduling. Unlike cron, it is designed for a single deferred command rather than a recurring pattern.

## Commands to remember
```bash
echo './cleanup.sh' | at now + 1 minute
atq
atrm 1
```
