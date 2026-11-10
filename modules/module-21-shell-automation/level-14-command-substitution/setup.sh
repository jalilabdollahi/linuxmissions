#!/bin/bash
# Tag Without a Hash: make_tag.sh builds the release tag from VERSION, the
# commit hash and the date. Every failure inside it is hidden: `local x=$(...)`
# returns local's status, the function's status is its last echo, and the
# VERSION file (saved on Windows) ends in CRLF.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin .mockgit

printf '1.2.0\r\n' > VERSION
printf '3f9c2ab71d0e4c5b8a6f2e19d7c3b0a4e5f61728\n' > .mockgit/HEAD
echo "app-1.1.9-8c41d07-20261020" > release.tag

cat > bin/git <<'MOCK'
#!/bin/bash
# bin/git - stand-in for git in the CI checkout. Only `git rev-parse [--short] HEAD`
# works. It reads the commit from .mockgit/HEAD in the current directory and,
# like real git outside a repository, fails with status 128 when there is none.
if [ "$1" = rev-parse ] && [ "${!#}" = HEAD ]; then
  if [ -f .mockgit/HEAD ]; then
    sha="$(cat .mockgit/HEAD)"
    if [ "$2" = --short ]; then echo "${sha:0:7}"; else echo "$sha"; fi
    exit 0
  fi
  echo "fatal: not a git repository (or any of the parent directories): .git" >&2
  exit 128
fi
echo "git (CI stand-in): only 'git rev-parse [--short] HEAD' is available" >&2
exit 1
MOCK
chmod +x bin/git

cat > make_tag.sh <<'SCRIPT'
#!/bin/bash
# make_tag.sh - write the release tag (app-<version>-<sha>-<date>) to release.tag
# The release job runs it in the checkout as:  PATH="$PWD/bin:$PATH" ./make_tag.sh

make_tag() {
  local version=$(cat VERSION)
  local sha=$(git rev-parse --short HEAD)
  local day=${TAG_DATE:-$(date +%Y%m%d)}
  echo "app-$version-$sha-$day"
}

tag=$(make_tag)
if [ $? -ne 0 ]; then
  echo "make_tag: could not build the tag" >&2
  exit 1
fi
echo "$tag" > release.tag
echo "release tag: $tag"
SCRIPT
chmod +x make_tag.sh

cat > INCIDENT.txt <<'TXT'
Release 1.2.0 went out tagged  app-1.2.0--20261110  (no commit hash).
The CI runner had lost its .git directory, git failed, and make_tag.sh still
exited 0 and wrote release.tag. In the CI log the tag also looked cut off.

To play the broken CI runner here:   mv .mockgit .mockgit.off
To bring the commit back:            mv .mockgit.off .mockgit
Run the job like CI does:            PATH="$PWD/bin:$PATH" ./make_tag.sh; echo $?
TXT
