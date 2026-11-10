# Cut the Next Release

## Why it works
Semantic versioning maps the kind of change to the part of the number that moves: a breaking change bumps
MAJOR (and resets the others), a feature bumps MINOR, a fix bumps PATCH. Conventional Commits makes that
machine-readable: `feat:`, `fix:`, a `!` before the colon, or a `BREAKING CHANGE:` footer in the body. The
highest level present wins, whatever its position in the log, so one `feat!:` buried among fixes still means
a new major version.

Precedence is the second half: `1.0.0-rc.1` is lower than `1.0.0`, and the dot-separated parts of a
prerelease compare as numbers when they are numeric (`rc.10` > `rc.2`). Plain `sort -V` gets the first one
wrong; swapping the dash for a `~` makes GNU `sort -V` behave like semver for tags like these.

## Common mistakes
- Grepping for the word "breaking" anywhere: a docs commit or a `Refs:` line can mention it.
- Writing `v2.4.0` into VERSION, or rewriting package.json with an editor that reformats it.
- Treating `latest`, `nightly-...` or `v2.3` as release tags.

## Next step
`git tag --sort=-version:refname` does a similar job on a real repo, and `jq '.version = "2.4.0"' package.json`
is the safer way to edit JSON (write to a temporary file, then `mv`).
