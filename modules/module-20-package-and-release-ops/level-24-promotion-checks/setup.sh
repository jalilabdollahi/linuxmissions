#!/bin/bash
# Promotion Checks: policy + spec + keyring + prod version and three sample builds written by the
# level-local helper mkbuild.py (real tar.gz, SHA256SUMS and a detached OpenPGP signature made with
# the shared test key). The version gate uses 1.10.x against prod 1.9.x so string comparison fails.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
MOCKS="$HERE/../../../mocks"
mkdir -p keys prod builds .lm
python3 "$MOCKS/packages/pgp.py" export key1 --uid "LinuxMissions Release <release@example.org>" > keys/release.gpg || exit 1
N=$((2 + RANDOM % 7))
echo "1.9.$N" > prod/VERSION
NEW="1.10.$((RANDOM % 5))"
names=(build-a build-b build-c)
# shuffle which sample gets which scenario
order=($(printf '%s\n' good rebuild nochangelog | sort -R))
for i in 0 1 2; do
  d="builds/${names[$i]}"
  case "${order[$i]}" in
    good)        python3 "$HERE/mkbuild.py" "$d" "$NEW"; echo "${names[$i]} PROMOTE" >> .lm/expected.txt ;;
    rebuild)     python3 "$HERE/mkbuild.py" "$d" "1.9.$N"; echo "${names[$i]} REJECT version" >> .lm/expected.txt ;;
    nochangelog) python3 "$HERE/mkbuild.py" "$d" "1.10.$((5 + RANDOM % 4))" --changelog missing; echo "${names[$i]} REJECT changelog" >> .lm/expected.txt ;;
  esac || exit 1
done
cp "$HERE/mkbuild.py" .lm/mkbuild.py 2>/dev/null
cat > ARTIFACT_SPEC.md <<'SPEC'
# Artifact spec: agent tarball

File name      agent-<version>.tar.gz
Layout         everything under one top directory agent-<version>/
Modes          directories 0755; files under bin/ 0755; files under conf/ 0640; every other file 0644
Owner          root:root (uid 0, gid 0)
Never shipped  .DS_Store files, object files (*.o), editor backups (*~)
(Timestamps and the gzip header are checked by the build pipeline, not by the promotion gate.)
SPEC
cat > PROMOTION_POLICY.md <<'POL'
# Promotion policy: staging -> prod

Tool           ./promote.sh BUILD_DIR
Output         one line on stdout, nothing else:
                 PROMOTE                      exit status 0
                 REJECT: <gate>               exit status 1   (anything may follow the gate name after a space)
Build dir      agent-<version>.tar.gz, SHA256SUMS, SHA256SUMS.sig, CHANGELOG.md

Gates, checked in this order; the first one that fails is the reason:

  signature   SHA256SUMS.sig is a valid detached signature of SHA256SUMS, made by a key in keys/release.gpg (use gpgv)
  checksum    every file listed in SHA256SUMS exists and matches its sha256
  version     the version in the artifact's file name is strictly newer than prod/VERSION (Debian version order: 1.10.0 is newer than 1.9.5)
  changelog   CHANGELOG.md has a heading "## <version> - <date>" for exactly this version
  layout      the tarball follows ARTIFACT_SPEC.md (top directory, modes, owner, no junk)

promote.sh finds prod/VERSION and keys/ next to itself, works from any directory, and changes nothing.
POL
