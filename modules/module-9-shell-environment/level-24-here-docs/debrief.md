# Newcomer Bootstrap

## Why it works
A heredoc is expanded when it is *written*, unless its delimiter is quoted.
That gave three tools for three jobs:

- team.env (`<<EOF`): TEAM and OWNER must be frozen at bootstrap time, so
  they are expanded, and wrapped in double quotes so `Ana Lima` reads back as
  one value.
- the .bashrc block (`<<EOF` with `\$`): the tools directory is known only
  now, so `$tools` expands; `\$PATH`, `\$USER` and `\$HOME` are escaped and
  stay as text, to be expanded every time a shell starts. The draft's unquoted
  `$PATH` froze bootstrap's PATH into the file forever.
- .bash_profile (`<<'EOF'`): nothing to expand at all.

Rerunning is safe because files that are fully owned by the script are
written with `>` (same content every time), and the block in the user's own
.bashrc is appended only when its marker line is not there yet.

## Common mistakes
- `<<'EOF'` for team.env: the file then says `TEAM=$TEAM`, which is empty in
  every later shell.
- Escaping too much: `\$tools` would write `$tools` into .bashrc, a variable
  that never exists at login.
- `>>` for .bash_profile: every rerun adds another `. ~/.bashrc` line, and
  login shells then read .bashrc twice (PATH gets the tools directory twice).

## Learn next
`<<-EOF` strips leading tabs, so heredocs can be indented in scripts (module
21). Tools like `envsubst` (gettext) fill in only the variables you name:
`envsubst '$TEAM $OWNER' < template`. The `# >>> ... >>>` marker pattern is
what conda and many installers use to update their block in place.
