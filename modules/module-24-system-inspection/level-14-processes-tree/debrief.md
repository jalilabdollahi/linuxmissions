# Kill the Whole Tree

## Why it works
Each process records its parent (`PPid`), so `ps` and `/proc` let you climb a
tree from any leaf to the root. The runner is a chain of supervisors: kill a
worker and its shard starts a new one, kill the shard and the dispatcher
starts a new shard, and so on. Only removing every layer at the same time, or
killing from the top down, stops it. The supervisor started the runner in its
own session, so its PID is also the process group ID, and `kill -- -PGID`
reaches the whole tree with one signal.

## Common mistakes
- Killing just the stuck worker: it comes back with a new PID, and the
  chain you wrote no longer exists.
- `pgrep -f 'job 7'`, which also finds `--job 70`.
- Killing from the bottom up by hand and racing the restarts, or killing
  the supervisor and forgetting that its children keep running as orphans.

## Next step
`pstree -ps PID` shows the ancestry of one process in a single line,
`pkill -P PID` kills the children of a process, and systemd does what
the supervisor did here with `KillMode=control-group`.
