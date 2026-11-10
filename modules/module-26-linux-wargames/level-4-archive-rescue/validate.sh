#!/bin/bash
# restored/ holds exactly dataset/reports/ with every file matching the
# vendor's hashes, nothing else, and no evil.sh anywhere.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected.sum ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
if find "$SANDBOX" "$SANDBOX/.." -maxdepth 6 -name evil.sh 2>/dev/null | grep -q .; then
  echo "❌ evil.sh was extracted: a member of the archive escaped its folder; delete it and extract more carefully"; exit 1
fi
if [ ! -d restored ]; then echo "❌ restored/ does not exist"; exit 1; fi
exp=$(awk '{ $1=""; sub(/^ +/, ""); print }' .lm-state/expected.sum | sort)
got=$(cd restored && find . -type f | sed 's#^\./##' | sort)
if [ -z "$got" ]; then echo "❌ restored/ has no files"; exit 1; fi
extra=$(comm -13 <(echo "$exp") <(echo "$got") | head -1)
if [ -n "$extra" ]; then echo "❌ restored/ holds more than the reports subtree (for example: $extra)"; exit 1; fi
missing=$(comm -23 <(echo "$exp") <(echo "$got") | head -1)
if [ -n "$missing" ]; then echo "❌ restored/ is missing a report file (for example: $missing)"; exit 1; fi
if ! (cd restored && sha256sum -c --quiet "$SANDBOX/.lm-state/expected.sum" >/dev/null 2>&1); then
  bad=$(cd restored && sha256sum -c "$SANDBOX/.lm-state/expected.sum" 2>/dev/null | grep -v ': OK' | head -1)
  echo "❌ a restored file does not match the vendor's checksum: $bad (was every part joined in the right order?)"; exit 1
fi
if [ "$(cd restored && find . -mindepth 1 -type d | wc -l)" -ne "$(echo "$exp" | xargs -d '\n' -n1 dirname | sort -u | awk '{n=split($0,a,"/"); for(i=1;i<=n;i++){p=p (i>1?"/":"") a[i]; print p} p=""}' | sort -u | wc -l)" ]; then
  echo "❌ restored/ contains extra empty directories"; exit 1
fi
echo "✅ restored/ holds exactly the reports subtree, every file matches the vendor's SHA256SUMS, and nothing escaped"
