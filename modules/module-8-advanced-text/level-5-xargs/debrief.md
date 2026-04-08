# Parallel Grep

## What you practiced
`xargs -P` lets you fan out work across multiple processes. It is a simple way to speed up repetitive commands over a large file list.

## Commands to remember
```bash
find files -type f | xargs -P 4 grep -l 'needle'
xargs -I{} basename {}
```
