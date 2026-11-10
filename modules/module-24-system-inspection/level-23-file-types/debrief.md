# What Is It Really?

## Why it works
`file` ignores the name and reads the content against the "magic" database:
an ELF header, a PNG signature, a gzip header, a `#!` line. With
`--mime-type` the answer is a stable token you can match in a `case`, and
`-z` makes it look through the compression layer, so a gzipped script
becomes `text/x-shellscript` instead of just `application/gzip`. Extensions are
a convention for humans, and an attacker (or a careless user) can name
anything anything.

## Common mistakes
- Trusting the extension: an ELF called `holiday.jpg`, a PNG named `.sh`.
- Calling plain text with a `.sh` name a script, although it has no `#!` line.
- Forgetting `-z`, so every compressed file is just "archive", or splitting
  names with spaces because `$f` was not quoted.

## Next step
`xxd -l 16 FILE` shows the raw signature, `file -i` prints mime types with
the charset, and `binwalk` or `unzip -l` go deeper into archives. In real
forensics, hash the files (`sha256sum`) before touching them.
