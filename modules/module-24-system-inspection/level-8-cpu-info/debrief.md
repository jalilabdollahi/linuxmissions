# Cpu Info: Cleanup Sweep

## What you practiced
- This level focused on **Cpu Info** in a safe sandbox.
- The shortest path usually combines `find` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
find dir -name '*.tmp'
find dir -name '*.tmp' -delete
find dir -type f -exec rm {} \;
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: Use a targeted file search so you do not remove the wrong files.
