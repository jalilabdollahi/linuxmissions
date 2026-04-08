# Zombie Apocalypse

## What you practiced
A zombie is a child process that has already exited, but its parent has not collected the exit status with `wait()`. Zombies do not keep using CPU, but they still occupy a process table entry.

## Key insight
You do not kill a zombie directly. The real fix is to get its parent to reap it by calling `wait()`, or to terminate the parent so init can adopt and reap the zombie.

## Commands to remember
```bash
ps aux | grep defunct               # quick zombie clue
ps -o pid,ppid,stat,comm | awk '$3 ~ /^Z/ {print}'
kill $(cat parent.pid)              # stop the parent process
pstree -p                           # visualize parent/child relationships
```
