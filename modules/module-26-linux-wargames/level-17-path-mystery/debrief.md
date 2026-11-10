## What you did

You stopped debugging your own shell and reproduced CI's: a clean environment, non-interactive bash, a specific PATH and `BASH_ENV`. Three things stood in front of 2.4.1: an exported function defined in the `BASH_ENV` file (functions beat PATH), a stale `~/.local/bin` symlink, and a wrapper in `usr/local/bin`. The alias in `.bashrc` and the PATH line in `.profile` only affect interactive or login shells, so they are not part of the CI problem.

## Common mistakes

- Testing with `type -a` in your login shell: it shows the alias and your own PATH, not CI's.
- Deleting `.ci_env` entirely: it also carried `DEPLOY_ENV=prod`.
- Overwriting the old binary with the new one "fixes" the output but breaks the other team that pins 1.x.

## Next

`bash -x` and `env -i bash --noprofile --norc -c 'type -a cmd'` reproduce a clean shell; `command -V name` and `declare -F name` tell function from file.
