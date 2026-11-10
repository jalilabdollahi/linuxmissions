# Drain Then Switch

## Why it works
`watch -g` (`--chgexit`) runs the command every `-n` seconds and exits the
first time its output differs from the first run. So the trick is to watch
a command whose output changes exactly once, at the event you are waiting
for: `ls -A spool | wc -l | grep -x 0` prints nothing until the count is 0.
`&&` then starts the switch within a second of the queue emptying.

`ls -A` matters: the in-flight uploads were `.upload-*.part` files, which
plain `ls` hides. Counting only visible files reports an empty queue
several seconds too early.

## Common mistakes
- `watch -g 'ls -A spool | wc -l'`: the output changes at the first upload
  (25 → 24), so watch exits long before the queue is empty.
- `watch` without `-g` never exits; Ctrl-C stops it, and `&&` then skips
  the switch.
- Polling without a pause (`until ...; do :; done`) burns a CPU core;
  always `sleep` in a loop.

## Next step
In scripts, the same wait is a loop: `until [ -z "$(ls -A spool)" ]; do sleep 1; done`.
Put a limit on any wait: `timeout 120 watch -g ...` gives up after two
minutes. On Linux, `inotifywait -e delete spool/` reacts to the change
without polling.
