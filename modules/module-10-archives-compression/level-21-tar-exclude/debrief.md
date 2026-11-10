# Pack Light

## Why it works
An exclude pattern without a slash is compared with every name component
of every path tar visits, so `--exclude=node_modules` catches both
node_modules dirs, and tar doesn't even descend into them. Patterns must
match the whole component: `.env` matches `.env` only, and `*.log` matches
names ending in .log but not `logs/` or `changelog.md`. `--exclude-vcs`
knows the version-control names (.git, .gitignore, .hg, .svn, ...) and
leaves look-alikes such as `.github` alone.

## Common mistakes
- `--exclude='.env*'` also drops `.env.example`, which the deploy needs as a
  template.
- `--exclude=logs` drops the logs/ dir together with `.keep`.
- `--exclude='*log*'` throws away `changelog.md`, `logger.js` and
  `logrotate.conf`.
- `--exclude='.git*'` drops `.github/` too.
- Forgetting the quotes: the shell expands `*.log` against the current
  directory before tar sees it.

## Learn next
`-X .tarignore` reads patterns from a file you can keep in the repo, and
`--exclude-caches` skips dirs that carry a CACHEDIR.TAG. For a git project,
`git archive --format=tar.gz -o release.tar.gz --prefix=app/ HEAD` packs
exactly the committed files and never sees untracked secrets.
