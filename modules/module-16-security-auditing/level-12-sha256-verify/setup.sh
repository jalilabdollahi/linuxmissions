#!/bin/bash
# Checksums That Won't Check. release/ holds six downloaded files and the
# vendor's SHA256SUMS: 12 lines, GNU style ("hash  name", "hash *name") and BSD
# style ("SHA256 (name) = hash") mixed, with CRLF endings (GNU coreutils 9.x
# tolerates the CR, older versions do not), six of them for files that were not
# downloaded. Of the six that matter, two have a "dist/" path prefix and one has
# a single space: a plain `sha256sum -c --ignore-missing` silently verifies only
# some of them. One downloaded file is corrupted (random which).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf release quarantine verify.log .lm-state; mkdir -p release quarantine .lm-state
sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || true; }
if ! command -v sha256sum >/dev/null 2>&1; then sha() { shasum -a 256 "$1" | cut -d' ' -f1; }; fi

have=(agent-1.8.0-linux-amd64.tar.gz agent-1.8.0-linux-arm64.tar.gz agent-1.8.0-darwin-arm64.zip agent-1.8.0-src.tar.gz install.sh agent-1.8.0-docs.pdf)
missing=(agent-1.8.0-windows-amd64.zip agent-1.8.0-freebsd-amd64.tar.gz agent-1.8.0-amd64.deb agent-1.8.0-x86_64.rpm agent-1.8.0-linux-armv7.tar.gz agent-1.8.0-checksums.sig)
for f in "${have[@]}"; do
  { echo "# $f (demo payload)"; for i in 1 2 3 4 5 6 7 8; do echo "$RANDOM$RANDOM $RANDOM $RANDOM $RANDOM"; done; } > "release/$f"
done
bad=${have[RANDOM % ${#have[@]}]}
echo "$bad" > .lm-state/bad

# build the list (hashes of the pristine files), then corrupt one
# Formats of the six downloaded files' lines (shuffled over the files):
#   gnu2   "hash  name"            fine
#   bsd    "SHA256 (name) = hash"  fine for GNU sha256sum -c
#   star   "hash *name"            fine (binary mode marker)
#   gnu1   "hash name"             ONE space: "improperly formatted", skipped with a warning
#   dist   "hash  dist/name"       path prefix: with --ignore-missing silently never verified
#   bsddist "SHA256 (dist/name) = hash"  both problems for a BSD line: prefix again
kinds=($(printf '%s\n' gnu2 bsd star gnu1 dist bsddist | awk -v s="$RANDOM" 'BEGIN{srand(s)} {print rand() "\t" $0}' | sort -n | cut -f2))
fmt() {  # fmt KIND NAME HASH
  case "$1" in
    gnu2)    printf '%s  %s\r\n' "$3" "$2" ;;
    bsd)     printf 'SHA256 (%s) = %s\r\n' "$2" "$3" ;;
    star)    printf '%s *%s\r\n' "$3" "$2" ;;
    gnu1)    printf '%s %s\r\n' "$3" "$2" ;;
    dist)    printf '%s  dist/%s\r\n' "$3" "$2" ;;
    bsddist) printf 'SHA256 (dist/%s) = %s\r\n' "$2" "$3" ;;
  esac
}
{
  i=0
  for f in "${have[@]}"; do fmt "${kinds[i]}" "$f" "$(sha "release/$f")"; i=$((i + 1)); done
  j=0
  for f in "${missing[@]}"; do
    k=$(( j % 3 )); j=$((j + 1))
    h=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    case $k in 0) fmt gnu2 "$f" "$h" ;; 1) fmt bsd "$f" "$h" ;; 2) fmt star "$f" "$h" ;; esac
  done
} | awk -v s="$RANDOM" 'BEGIN{srand(s)} {print rand() "\t" $0}' | sort -n | cut -f2- > release/SHA256SUMS

# corrupt one downloaded file: change one line, keep the size
sed -i.orig '2s/^./X/' "release/$bad" && rm -f "release/$bad.orig"

: > .lm-state/expected
for f in "${have[@]}"; do
  if [ "$f" = "$bad" ]; then echo "$f FAILED"; else echo "$f OK"; fi
done > .lm-state/expected
for f in "${have[@]}"; do printf '%s %s\n' "$f" "$(sha "release/$f")"; done > .lm-state/hashes
