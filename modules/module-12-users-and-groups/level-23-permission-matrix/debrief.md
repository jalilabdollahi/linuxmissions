# Permission Matrix: Backup Bundle

## What you practiced
- This level focused on **Permission Matrix** in a safe sandbox.
- The shortest path usually combines `tar` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
tar -czf backup.tar.gz folder/
tar -tf backup.tar.gz
gzip file.txt
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: Use tar with create, gzip, and file flags.
