# Split the Streams

## Why it works
Every program starts with three open streams: 0 (stdin), 1 (stdout) and 2
(stderr). The terminal shows 1 and 2 mixed together, but they are separate, and
redirections point each one somewhere else. `2>&1` copies whatever stream 1 points
to *at that moment*, so in `>> all.log 2>&1`, stdout is first pointed at the file
and stderr then follows it. Both open the file in append mode, so each run's lines
stay in the order they were printed and the second run lands after the first.

## Common mistakes
- `./nightly.sh 2>&1 >> all.log`: stderr is copied from stdout while stdout is
  still the terminal, so the warnings never reach the file.
- `> all.log` for the second run truncates the file and loses the first run.
- `./nightly.sh > all.log 2> all.log` opens the file twice, and the two streams
  overwrite each other's bytes.

## Learn next
`&>> file` is bash shorthand for `>> file 2>&1`. `2> /dev/null` throws errors
away, and `cmd 2>&1 | less` pipes both streams. How stderr behaves in pipes, and
`PIPESTATUS`, is the next level's topic. In cron, `>> job.log 2>&1` at the end of
the line keeps all of a job's output.
