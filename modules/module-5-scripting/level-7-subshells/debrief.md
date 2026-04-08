# Parallel Launch

## What you practiced
Background jobs and `wait` are the foundation for simple parallelism in shell scripts. This works well when tasks are independent and you only need to join them at the end.

## Commands to remember
```bash
./task-a.sh &
./task-b.sh &
./task-c.sh &
wait
```
