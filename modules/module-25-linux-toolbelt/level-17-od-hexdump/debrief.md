# Od Hexdump: Schedule Entry

## What you practiced
- This level focused on **Od Hexdump** in a safe sandbox.
- The shortest path usually combines `crontab` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
crontab -l
printf '%s\n' '15 2 * * * /usr/local/bin/nightly-check' > crontab.txt
cat crontab.txt
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: This mission is about cron field order and exact syntax.
