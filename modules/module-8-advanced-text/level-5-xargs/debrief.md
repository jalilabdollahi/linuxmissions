# Quarantine Sweep

## Why it works
`xargs` turns a list on standard input into arguments for a command. By default it
splits on blanks and newlines and treats quotes specially, so `meeting notes 12.txt`
becomes three arguments and `dana's export.txt` stops xargs with "unmatched single quote".
`grep --null` (and `find -print0`) end each name with a NUL byte, the one character a
file name can never contain. `xargs -0` splits on that alone, so every name arrives intact.

## Common mistakes
- `grep -rl KEY files | xargs mv -t quarantine/` works only while no name contains a
  space or quote. It fails on exactly the files you most need to move.
- `grep -i` moves the files that only mention *nebula_key*. Search for exactly what was asked.
- `rm` or `mv` first and check afterwards. Run the pipeline with `echo` in front of the command
  (`xargs -0 -I{} echo mv {} quarantine/`) to see what it would do.

## Next step
`xargs -P 4` runs up to 4 commands in parallel, which helps with slow jobs like
compressing or uploading files (`find . -name '*.log' -print0 | xargs -0 -P 4 -n 1 gzip`).
`find files -type f -exec grep -q KEY {} \; -exec mv {} quarantine/ \;` does the same
job without xargs.
