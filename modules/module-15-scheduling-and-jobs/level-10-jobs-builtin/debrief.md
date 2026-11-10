# Three Shards, Three Answers

## Why it works
Each `&` gave bash a new job (`%1`, `%2`, `%3`), all running at once, and `$!` its PID.
`wait ID` blocks until that one process ends and sets `$?` to its exit status, so you can
collect the statuses one by one while the others keep running. Waiting by PID is the safe
form: the moment bash reports a finished job (`[2]- Exit 3`), its job spec `%2` is
removed, while the PID's status is kept for `wait`.

## Common mistakes
- `wait` with no argument waits for every job but returns 0, so all three would look fine,
  even the shard that imported nothing (exit 4).
- `./import.sh eu; ./import.sh us; ...` gets the right codes but takes three times as long.
- `wait %1; ...; wait %2` when job 2 finished first: once `wait %1` returns, bash reports
  and forgets the finished job 2, and `wait %2` fails with "no such job" (status 127).

## Next step
`wait -n` returns as soon as any job finishes (with its status), and in bash 5.1+
`wait -n -p var` also tells you which one. In scripts, `set -m` enables job specs like `%1`.
