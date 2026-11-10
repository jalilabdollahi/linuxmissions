# Wait for Ready

## Why it works
`until ./probe; do ... done` runs the body as long as `./probe` fails, and stops the moment
it succeeds. The script then ends with the exit status of its last command, 0. `sleep 2`
keeps the polling gentle: about one request every 2 seconds, so the app sees 15 probes in
30 s instead of thousands. `$SECONDS` is a bash counter that you can reset, which makes the
deadline a one-line test, and `${1:-30}` gives the caller control over the timeout.

## Common mistakes
- A loop without `sleep` ("busy waiting"): it burns a CPU and floods the app with
  connections while it is trying to start.
- `sleep 30; ./probe`: always slow, and still fails when the app needs 31 seconds.
- Checking the deadline only after `sleep` with `-gt`: the script then waits up to one
  interval longer than promised. Fine for 2 s, surprising for long intervals.

## Next step
`timeout 30 bash -c 'until ./probe; do sleep 2; done'` builds the same thing from two
tools. For network services, `curl --retry 15 --retry-delay 2 --retry-connrefused URL`
has the loop built in. Exponential backoff (2, 4, 8 s ...) is kinder to a struggling service.
