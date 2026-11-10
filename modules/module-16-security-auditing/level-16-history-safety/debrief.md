# Typed It in Plain Text

## Why it works
Bash keeps an in-memory list of commands and writes it to `~/.bash_history` when a shell exits, so
anything you type, passwords included, is stored as plain text. `sed -i '/pattern/d'` removes the
matching lines and keeps all the others in order. With `HISTCONTROL=ignorespace`, a command whose first
character is a space is never added to the history, so `' mysql -pSECRET'` leaves no trace. Because
`.bashrc` is read top to bottom and a later assignment wins, the new line has to come after the old
`HISTCONTROL=ignoredups` (or replace it with `ignoreboth`).

## Common mistakes
- A pattern like `/password/Id` also deletes `grep -i password ...`, a harmless line.
- `grep -v ... > file.new && mv file.new .bash_history` quietly turns a 600 file into 644.
- Cleaning the file while the shell still has the commands in memory: it writes them back on exit
  (`history -c` clears the in-memory list).
- Treating the cleanup as enough: a password that was typed on a shared box should be changed.

## Next step
Better than hiding a typed secret is not typing it: let the client prompt (`mysql -p`), use
`~/.my.cnf` with mode 600, or read it from a file. `HISTIGNORE='*password*:*token*'` drops matching commands.
