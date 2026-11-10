# Find the Right Package

## Why it works
`apt-cache search` matches every word you give it against package names and
descriptions, so adding words from what the tool *is* ("command-line", "validator")
filters out the library, headers and docs that merely mention JSON Schema. Always
confirm with `apt-cache show NAME`, which prints the full description and the Section.

## Common mistakes
- Taking the first hit. Ranking is alphabetical, not "best match"; the `python3-`
  library and `-dev` package often come first.
- Writing the whole search line (`name - description`) into the file instead of the name.
- Picking a package that only looks similar: a schema *generator* is a command-line
  tool too, but it does not validate.

## Next step
`apt-cache search --names-only` for name-only matches, `apt-cache policy NAME` for the
version you would get, and `apt-file search /usr/bin/NAME` (when installed) to find which
package ships a given command.
