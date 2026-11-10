# A Program That Needs A Terminal

## Why it works
Programs ask `[ -t 1 ]` (or `isatty`) whether their output goes to a terminal,
and many change behaviour when it does not. `script -q -c CMD FILE` gives CMD a
pseudo-terminal, so the check passes, and logs every byte it writes. That log
is raw terminal traffic: colours are escape sequences, every newline is
`\r\n`, and the spinner is a line that keeps returning to column 0 with `\r`.
To get what a person saw, remove the escape sequences and, on each line, keep
only the text after the last `\r`. `script` also adds its own header and
footer, which `grep -v` removes.

## Common mistakes
- Running `script` with the shell's own input attached: it forwards everything
  typed (or piped) into the pseudo-terminal and can swallow the next commands;
  `</dev/null` avoids that when you only want to record a command.
- `./vendor-diag > file` or `| tee`: the tool sees a pipe and aborts.
- `tr -d '\r'` alone glues the spinner frames to the first report line,
  because the frames were overwritten on screen, not deleted from the stream.
- Leaving the escape codes in: support's tooling shows them as `^[[32m`.

## Learn next
`col -b` and `ansifilter` (if installed) also flatten terminal output, and
`script -T timingfile` plus `scriptreplay` replays a session in real time.
