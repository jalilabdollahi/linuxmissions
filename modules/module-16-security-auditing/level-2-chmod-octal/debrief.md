# Never Loosen

## Why it works
A policy like "at most 640" is a mask: the new mode is the old mode with every bit that
is not in 640 cleared (`old & 640`). `chmod g-w,o-rwx` does exactly that kind of
subtraction, so a file that is already stricter is left untouched while a 777 file comes
down. Setting `chmod 640 *` is also "compliant", but it silently adds read access to
the 600 and 400 secrets, which is worse than the problem you set out to fix.

Owner execute is not in 640 either, so plain data files lose `x` for everyone, and
scripts in `bin/` (limit 750) keep `u+x` but lose group write and anything for others.

## Common mistakes
- `chmod -R 640 app`: loosens secrets, strips the execute bit from `bin/` scripts and
  turns folders into things nobody can enter.
- Forgetting that names can contain spaces: `find -exec ... {} +` handles them, a bare
  `for f in $(find ...)` does not.

## Next step
`chmod --reference=FILE other` copies a mode between files, and `find -perm /go+w`
finds files that group or others can write, which is a handy audit query.
