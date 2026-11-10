# Stale Package Lists

## Why it works
apt never asks the repository "what is new?" at install time. It reads the index files it
downloaded earlier (under `/var/lib/apt/lists/`) and decides from those. `apt update`
refreshes the indexes, after which `apt-cache policy` shows the new **Candidate**. Nothing
is installed by it: that is a separate `apt install` or `apt upgrade`.

## Common mistakes
- Writing the version you expect into the file without updating: the validator asks apt
  itself, so a guess fails.
- Running `apt upgrade` or `apt install agentd` instead of `apt update`: that installs the
  new build, which this task did not ask for.
- Forgetting that `apt update` and `apt upgrade` are different: update fetches lists,
  upgrade changes packages.

## Next step
`apt list --upgradable` shows what a refreshed index lets you upgrade, and
`apt-cache policy` also lists every version table with its repository, which is the first
place to look when apt offers something unexpected.
