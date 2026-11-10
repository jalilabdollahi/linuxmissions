# Flag Day

## Why it works
JSON is data, so the safe way to edit it is with a tool that understands the structure.
A jq path such as `.flags.new_checkout.regions.eu` addresses exactly one value, while a
text search for "eu" would find several. jq keeps the order of the keys and prints the whole
document on stdout; writing that to a temp file and moving it over the original means a failure
in the middle never leaves you with half a file.

## Common mistakes
- `jq ... flags.json > flags.json` empties the file: the shell opens (and truncates) the output
  before jq reads the input. Without a backup that is data loss.
- Using `..` or a recursive search and flipping dark_mode's eu region too.
- Editing by hand and leaving a trailing comma, which makes the file invalid.

## Next step
`jq --arg t beta-12 '.testers += [$t]'` passes values safely from shell variables, and
`jq -S .` sorts keys when you want a canonical diff between two files.
