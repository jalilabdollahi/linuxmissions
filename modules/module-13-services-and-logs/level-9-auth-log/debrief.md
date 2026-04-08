# Auth Log: Link Repair

## What you practiced
- This level focused on **Auth Log** in a safe sandbox.
- The shortest path usually combines `ln` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
ln -s target linkname
ls -l current.conf
readlink current.conf
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: This task wants a symbolic link, not a copy.
