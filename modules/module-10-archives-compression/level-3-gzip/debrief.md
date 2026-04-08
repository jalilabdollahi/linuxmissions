# Gzip: Event Counter

## What you practiced
- This level focused on **Gzip** in a safe sandbox.
- The shortest path usually combines `grep` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
grep -c '^pattern$' file.txt
grep PATTERN file.txt | wc -l
wc -l file.txt
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: Count matching lines instead of copying them out by hand.
