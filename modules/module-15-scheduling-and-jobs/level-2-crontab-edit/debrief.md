# Crontab Edit: Alert Filter

## What you practiced
- This level focused on **Crontab Edit** in a safe sandbox.
- The shortest path usually combines `grep` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
grep 'ALERT' file.log
grep -n PATTERN file.log
grep -v PATTERN file.log
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: Look for a filtering command that keeps only the alert lines in crontab-edit.log.
