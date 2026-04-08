# Play Nice

## What you practiced
Niceness controls how politely a CPU-bound process shares time with the rest of the system. Higher niceness means lower scheduling priority.

## Niceness scale
The scale runs from `-20` (highest priority) to `19` (lowest priority). Regular users can usually increase niceness, but only root can assign negative values.

## Commands to remember
```bash
nice -n 15 ./heavy.sh            # start a new low-priority process
ps -o pid,ni,cmd -p 12345        # inspect niceness for one PID
renice 10 -p 12345               # change niceness of an existing process
top                              # view process priority live
```
