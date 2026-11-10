# Scaffolding

## Why it works
Brace expansion is the first expansion bash performs, and it is pure text
generation: `{a,b}` turns into two words, `{01..12}` into twelve, and several
braces in one word produce every combination. Nothing has to exist on disk, so
it is the tool for *creating* names. `cp config.yaml{,.bak}` expands to
`cp config.yaml config.yaml.bak`, because the first item in the braces is empty.

## Common mistakes
- `{1..12}` gives `1 ... 12`. Sorting then puts `10` before `2`, and tools that
  expect `MM` break. A leading zero on either end (`{01..12}`) pads them all.
- `mkdir "data/2026/{01..12}"` creates one directory literally named `{01..12}`:
  quotes switch brace expansion off. So does a space: `{api, web}`.
- Braces generate names and globs match existing ones: `ls svc/*/dev` works
  only after the directories exist, `ls svc/{api,web}/dev` complains about any
  that are missing.

## Learn next
`{a..z}` and `{0..100..10}` (a step) also work, and `mv file.{txt,md}` renames
in one go. `tree -d data svc` (or `find ... -type d`) shows what was created.
