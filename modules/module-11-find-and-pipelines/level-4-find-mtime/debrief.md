# Find Mtime: Noise Dedup

## What you practiced
- This level focused on **Find Mtime** in a safe sandbox.
- The shortest path usually combines `sort` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
sort file.txt
sort file.txt | uniq
uniq -c sorted.txt
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: This is a sorting task followed by deduplication.
