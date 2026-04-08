# Filesystem Labels: Capacity Report

## What you practiced
- This level focused on **Filesystem Labels** in a safe sandbox.
- The shortest path usually combines `du` with careful redirection or inspection.
- Keep intermediate outputs small and verify them before moving on.

## Commands to remember
```bash
du -s datasets/*
du -sh datasets/* | sort -h
sort -n report.txt | tail -n 1
```

## Key insight
- Start with inspection, then apply the smallest command that achieves the goal.
- Hint ladder summary: Measure directory sizes before deciding which one is largest.
