# Lost on Login

## Why it works
Bash picks its startup files by the kind of shell:
- a **login** shell (SSH, console login, `bash -l`) reads `/etc/profile`, then the
  first of `~/.bash_profile`, `~/.bash_login`, `~/.profile` that exists, and stops;
- an **interactive non-login** shell (a new terminal tab, `bash -i`) reads only `~/.bashrc`.

Because `.bash_profile` existed, `.profile` was never read at all. Now the export
lives in `.bashrc` and `.bash_profile` loads it with `. ~/.bashrc`, so both kinds of
shell reach the same single line.

## Common mistakes
- Pasting the export into all three files. It works today, but next month someone
  changes one copy and the shells disagree again.
- Deleting `.bash_profile` to make bash fall back to `.profile`: login shells now
  get the variable, but you lose EDITOR and `~/bin`, and terminal tabs still don't.
- Testing in the shell you are already in. Startup files run only when a shell
  starts; open a new one (`bash -l`, `bash -i`) or `source` the file.

## Learn next
Many distributions ship a `.bashrc` that starts with `case $- in *i*) ;; *) return;; esac`,
which stops early in non-interactive shells. Anything placed below that line is
invisible to `bash -l -c cmd` and to scripts, so environment variables are often
kept in `.profile`/`.bash_profile` and inherited by every child process instead.
`bash -x -l -c exit 2>&1 | less` shows every startup line as it runs.
