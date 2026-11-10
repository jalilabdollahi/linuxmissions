# Which Deploy?

## Why it works
When you type a name, bash checks, in order: aliases, functions, builtins,
and finally the directories of PATH from left to right. The first hit runs.
The three "deploys" were three layers of that list:

- terminal tabs read `.bashrc`, which defined an **alias**;
- the same `.bashrc` sourced `helpers.sh`, whose **function** was hiding
  right under the alias (which is why `unalias` "brought back" 1.4);
- login shells read only `.bash_profile`, whose **PATH** put the pinned 1.4
  directory before tools/bin.

Removing the alias and the function lets lookup fall through to PATH, and
fixing PATH makes the first match tools/bin/deploy. Having `.bash_profile`
source `.bashrc` means both kinds of shell now share one setup.

## Common mistakes
- Checking with `which deploy`: it only walks PATH, so it said tools/bin while
  the alias was still winning. `type -a` shows the whole truth.
- Testing in an old shell: it still has the alias and function in memory and
  may have the old path cached. `hash -r` clears the cache; for startup files,
  only a new shell is a real test.
- Deleting the old binaries "to be sure": rollbacks need them, and a
  hard-coded path in a function would just fail instead.

## Learn next
`command deploy` skips aliases and functions for one call, `\deploy` skips
just the alias, and `builtin cd` forces the builtin. `hash` lists the paths a
shell has cached. `declare -f deploy` prints a function's definition, and
`shopt -s extdebug; declare -F deploy` even shows the file and line it came from.
