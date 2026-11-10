# Corrupt Config

## Why it works
The file had four separate faults: merge-conflict markers around the very line
the ticket changed, a trailing comma (valid in JavaScript, not in JSON), smart
quotes pasted from a chat tool, and a duplicate key. The last one is the
dangerous one: most parsers, `jq` included, silently keep the later value, so
the file "works" with a timeout ten times too small. Rebuilding from the last
known good file and applying the ticket with `jq` removes all four at once and
guarantees nothing else drifted.

## Common mistakes
- Stopping when the checker turns green; it cannot know what the ticket asked for.
- Resolving the conflict markers by picking the wrong side.
- Retyping by hand: you can paste new smart quotes or lose a key.

## Next step
`diff <(jq -S . a.json) <(jq -S . b.json)` compares two JSON files ignoring
formatting and key order. `jq -e` makes a filter usable as a test.
