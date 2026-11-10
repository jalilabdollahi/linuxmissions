# One At A Time

## Why it works
`exec 9> sync.lock` opens a file descriptor on the lock file and keeps it for the life of
the script. `flock -n 9` asks the kernel for an exclusive lock on it: the first copy gets
it, every later copy fails immediately (`-n`) and exits with a message before it reaches
`catalog.db`. The lock belongs to the open file, so when a run dies, even with `kill -9`,
the kernel releases it. The `sync.lock` file may stay on disk; that is harmless, because
only the lock counts, not the file's existence.

## Common mistakes
- A pidfile (`[ -e sync.pid ] || echo $$ > sync.pid`): two copies can both pass the test
  before either writes, and a killed run leaves a pidfile that blocks every later sync.
- `flock 9` without `-n`: the second copy waits, so copies pile up behind the first one.
- Taking the lock with `flock -n file command &` in a script that goes on writing: the lock
  ends with that command, not with the script.

## Next step
You can also lock from the crontab line: `* * * * * flock -n /run/lock/sync.lock /opt/sync.sh`.
`flock -w 5` waits up to five seconds, and `flock -x -c 'cmd' file` runs one command under a lock.
