# Writing a LinuxMissions level

Every level teaches one real Linux skill through a small, believable problem.
A level is done only when `scripts/test_levels.py` passes for it.

## Files

```
modules/<module>/<level-N-slug>/
  mission.yaml    JSON (despite the extension): name, description, objective, xp,
                  difficulty, expected_time, concepts, module, level
  setup.sh        bash; $1 = sandbox path. Builds the broken / incomplete state.
  validate.sh     bash; $1 = sandbox path. exit 0 = solved, exit 1 = not yet.
  solution.sh     bash; $1 = sandbox path, run with cwd = sandbox. A reference
                  solution, written the way a player would type it.
  hint-1.txt  hint-2.txt  hint-3.txt
  debrief.md      shown after the level is solved
```

Do not rename or delete existing level folders: the folder name is the level id
saved in players' `progress.json`.

## Rules for setup.sh and validate.sh

1. **No free passes.** `validate.sh` must fail on the fresh sandbox.
2. **Check the result, precisely.** Compare content, modes, links and counts.
   "File exists" or "has at least 5 lines" is not a check. If the answer could be
   typed without doing the work (e.g. `echo 42 > answer.txt`), make the data large
   or messy enough that the player has to use the tool, or check side effects too.
3. **Useful failure messages.** One line starting `❌` that says what is still
   wrong without giving the answer (`❌ errors.txt has 3 lines, expected more`).
   Success prints one line starting `✅`.
4. **Runs as a normal user on Ubuntu**, no root, no network. Reference
   environment: `docker/Dockerfile` (the same image `./play.sh --docker` uses);
   a level may rely on any tool installed there. Prefer POSIX/GNU tools that also exist on
   macOS; when a task needs root or a real service (systemctl, useradd, mount),
   ship a small mock script in the sandbox and say so in the objective.
5. **Background processes** started by setup.sh must redirect output
   (`>/dev/null 2>&1 &`) and have the sandbox path in their command line, so the
   engine can stop them on reset.
6. Everything the level creates stays inside `$SANDBOX`.
7. **Shared mocks** for tools that need root, a daemon or the network live in
   `mocks/` (see `mocks/README.md`). setup.sh copies the ones it needs into the
   sandbox. A mock behaves like the real tool (same options, output format and
   exit codes); everything specific to the level (data, scenario, checks) stays
   in the level folder. Never generate levels from a shared template: each
   level's setup, validator, solution and hints are written for that level, and
   `scripts/check_duplicates.py` must report no issues.

## Mission text

- `description`: a one or two sentence situation ("The nightly backup job
  filled the disk and nobody knows which directory grew").
- `objective`: what must be true at the end, with exact file names. Say *what*,
  not *how*: don't name the command unless the level is about learning that
  command's syntax.
- `difficulty` and `xp`: beginner 100, intermediate 150, advanced 200, expert 300.
  - beginner: one command, one concept.
  - intermediate: two or three steps, or one tool with non-trivial options.
  - advanced: a pipeline or script, some investigation, data with traps
    (spaces in names, hidden files, mixed case, empty lines).
  - expert: multi-step incident, several tools, the player must find the problem.

## Hints (each one costs XP: 90%, 75%, 50%)

- **hint-1: where to look and what to ask.** No command. ("Which of these files
  were changed in the last day? `ls` alone won't tell you.")
- **hint-2: the tool and the options that matter**, with a pointer to
  `man <tool>` or `<tool> --help`. A partial example is fine.
- **hint-3: a working solution with a one-line explanation of each part.** It
  must actually work when typed into the game (the test runner does not check
  this, so try it).

Commands in hints are written to be typed at the `linuxmissions>` prompt: the
shell already starts in the sandbox, `$SANDBOX` is set, and `$SANDBOX/bin` is
first on PATH (ship mocks there so `crontab`, `apt`, `systemctl` reach the mock;
don't put files named like system commands in `bin/` unless that is the point). Multi-line input
(heredocs, if/for) works; `edit <file>` or `nano <file>` opens an editor.

## Debrief

Short markdown: what the player did and why it works, one or two common
mistakes, and one related command or option worth knowing next.
