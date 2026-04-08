# Rsync Delete: Restore Drill

## What you practiced
- This level focused on **Rsync Delete** in a safe sandbox.
- The shortest path usually combines `tar` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
tar -tf archive.tar.gz
tar -xzf archive.tar.gz
ls -R restored/
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: List the archive if you want to inspect it first, then extract it.
