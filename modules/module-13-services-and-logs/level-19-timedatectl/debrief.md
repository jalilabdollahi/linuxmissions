# Timedatectl: Config Rewrite

## What you practiced
- This level focused on **Timedatectl** in a safe sandbox.
- The shortest path usually combines `sed` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
sed 's/old/new/g' file.conf
sed -n '1,20p' file.conf
grep PATTERN file.conf
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: You need a stream editor or another text replacement tool.
