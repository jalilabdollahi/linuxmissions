# Bzip2: Field Extract

## What you practiced
- This level focused on **Bzip2** in a safe sandbox.
- The shortest path usually combines `cut` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
cut -d, -f2 file.csv
awk -F, '{print $2}' file.csv
column -s, -t file.csv
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: This is a delimiter-based column extraction task.
