#!/bin/bash
# verified/ has exactly the good tarball; the three bad tarballs are gone from
# the whole sandbox; report.txt has the right good/bad word for each mirror;
# vendor.gpg is untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/roles ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
h() { cksum < "$1" | tr ' ' :; }
good_h=$(awk '$2 == "good" { print $1 }' .lm-state/hashes)

[ "$(cksum < vendor.gpg 2>/dev/null)" = "$(cat .lm-state/keyring-sum)" ] || { echo "❌ vendor.gpg was changed or removed: it is the trust anchor"; exit 1; }

files=$(ls -A verified 2>/dev/null | grep -v '^agent-2.3.1.tar.gz.sig$')
if [ -z "$files" ]; then echo "❌ verified/ is empty: the verified tarball has not been moved there yet"; exit 1; fi
if [ "$files" != "agent-2.3.1.tar.gz" ]; then echo "❌ verified/ contains something besides the tarball ($(echo "$files" | head -1))"; exit 1; fi
vh=$(h verified/agent-2.3.1.tar.gz)
if [ "$vh" != "$good_h" ]; then
  role=$(awk -v x="$vh" '$1 == x { print $2 }' .lm-state/hashes)
  case "$role" in
    wrongkey)     echo "❌ the tarball in verified/ is signed by a key that is not the vendor's release key" ;;
    tampered)     echo "❌ the tarball in verified/ does not match its signature: it was modified after signing" ;;
    wrongversion) echo "❌ the tarball in verified/ comes with a signature for a different file (another version)" ;;
    *)            echo "❌ the file in verified/ is not one of the downloaded copies" ;;
  esac
  exit 1
fi
# no untrusted tarball may remain anywhere
while IFS= read -r f; do
  fh=$(h "$f")
  role=$(awk -v x="$fh" '$1 == x && $2 != "good" { print $2 }' .lm-state/hashes)
  if [ -n "$role" ]; then echo "❌ an untrusted tarball is still on disk: $f"; exit 1; fi
done < <(find . -path ./.lm-state -prune -o -type f -name '*.tar.gz' -print)
if [ ! -f report.txt ]; then echo "❌ report.txt does not exist yet"; exit 1; fi
want=$(awk '{ print $1, ($2 == "good" ? "good" : "bad") }' .lm-state/roles | LC_ALL=C sort)
got=$(tr -d '\r' < report.txt | sed -e 's|^mirrors/||' -e 's|/ | |' | awk 'NF >= 2 { print $1, tolower($2) }' | LC_ALL=C sort)
if [ "$got" != "$want" ]; then
  n=$(printf '%s\n' "$got" | grep -c .)
  if [ "$n" != 4 ]; then echo "❌ report.txt has $n usable lines, expected one per mirror (4): name and good/bad"; exit 1; fi
  bad=$(diff <(echo "$want") <(echo "$got") | grep '^>' | head -1 | cut -d' ' -f2)
  if [ -n "$bad" ]; then echo "❌ report.txt has the wrong verdict for $bad"; else echo "❌ report.txt does not name every mirror exactly once"; fi
  exit 1
fi
echo "✅ only the vendor-signed tarball is left (in verified/), and the report names every mirror correctly"
exit 0
