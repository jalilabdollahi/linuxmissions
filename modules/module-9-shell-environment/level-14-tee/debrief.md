# Three Copies

## Why it works
`tee` reads stdin and writes every line twice: into its file and to stdout.
Put in the middle of a pipeline, it saves a copy of the stream at that point
and lets the stream flow on, so one run of gen-events fed all three outputs.
The second `tee` saved the filtered stream before `wc -l` counted it, which
guarantees the count matches errors.log.

## Common mistakes
- Running the producer once per output. With live data (a log tail, a network
  capture, `ps`, a flaky API) each run is different, and the three files no
  longer describe the same thing.
- `grep error` instead of `grep 'level=error'`: free text such as "retrying
  after upstream error" matches too. Match the field, not the word.
- `cmd | tee file > /dev/null` is fine, but `cmd > file | tee ...` sends
  nothing into the pipe: stdout already went to the file.

## Learn next
`tee -a` appends instead of overwriting (module 25). Bash can feed tee into
another command directly: `cmd | tee >(grep -c level=error > count.txt) > raw`
uses process substitution. And `sudo tee /etc/file` is the usual way to write
a root-owned file from a pipe, since `sudo cmd > /etc/file` redirects as you.
Saving to a file first and filtering the file afterwards also works; tee does
it in one pass, while you still watch the stream.
