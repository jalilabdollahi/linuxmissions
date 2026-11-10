# Needle in a Haystack

## Why it works
`find` walks the whole tree, hidden folders included, and prints one path per
line, which is exactly the format `>` writes to `found.txt`. `-name '*.py'`
matches names that end in `.py` (so not `setup.py.bak` or `parser.pyc`), and
`-type f` drops `tools.py`, which is a directory.

## Common mistakes
- Leaving the pattern unquoted: if the current folder has a .py file, the shell
  expands `*.py` to that name and find searches for only that one file.
- `ls -R | grep .py` misses hidden folders and also matches `.pyc` (the `.` in grep means "any character").

## Learn next
`find . -name '*.py' -not -path '*/.venv/*'` skips the virtualenv, and
`find . -name '*.py' | wc -l` counts the results. `-iname` ignores case.
