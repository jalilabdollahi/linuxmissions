# Command Not Found for Everything

## Why it works
A login starts with the environment PAM builds from `/etc/environment`, which is plain
`KEY=value` text: `$PATH` in it is not expanded. Then bash sources `/etc/profile` (and
`profile.d/*.sh` through it) and finally only the first of `~/.bash_profile`, `~/.bash_login`,
`~/.profile` that exists. So a forgotten `.bash_profile` hid every fix made in `.profile`. The
trailing colon in `profile.d` left an empty PATH component (the current directory), and the
legacy file plus `.profile` added the same directory again. Each fault was in a different file,
and the PATH printed at the end showed all of them at once.

## Common mistakes
- Editing `.profile` when `.bash_profile` exists.
- Writing `$PATH` into `/etc/environment`.
- Leaving a trailing `:` after the last directory.

## Next step
`bash -lc 'echo $PATH'` shows the PATH of a real login shell, `bash -x -l` traces which files are read,
and a `.bash_profile` that contains `[ -f ~/.profile ] && . ~/.profile` keeps both working.
