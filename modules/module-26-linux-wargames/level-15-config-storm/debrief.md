# Config Storm: Metric Sum

## What you practiced
- This level focused on **Config Storm** in a safe sandbox.
- The shortest path usually combines `awk` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
awk -F, 'NR>1 {sum += $2} END {print sum}' file.csv
cut -d, -f2 file.csv
paste -sd+ numbers.txt | bc
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: This is a numeric aggregation task.
