#!/bin/bash
# MANIFEST.tsv must equal the manifest computed at setup; the tree must still produce it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f MANIFEST.tsv ] || { echo "❌ MANIFEST.tsv does not exist yet (it goes in this folder, next to backup/)"; exit 1; }
exp=.lm-state/expect.tsv

# the tree must be unchanged
now=$(cd backup && {
  find . -type f -print0 | while IFS= read -r -d '' f; do
    printf '%s\t%s\t%s\t%s\n' "$f" "$(stat -c %s "$f")" "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -d' ' -f1)"
  done
  find . -type l -print0 | while IFS= read -r -d '' l; do printf '%s\tsymlink\t%s\n' "$l" "$(readlink "$l")"; done
} | LC_ALL=C sort)
if [ "$now" != "$(cat $exp)" ]; then echo "❌ the contents of backup/ changed (files, modes or links): the manifest must describe the tree as it was"; exit 1; fi

if grep -q $'\r' MANIFEST.tsv; then echo "❌ MANIFEST.tsv contains carriage returns"; exit 1; fi
if cmp -s MANIFEST.tsv "$exp"; then echo "✅ MANIFEST.tsv matches every file and link in backup/"; exit 0; fi

if grep -q '^\./MANIFEST' MANIFEST.tsv || grep -q 'MANIFEST.tsv' MANIFEST.tsv; then echo "❌ the manifest lists itself: it belongs outside backup/"; exit 1; fi
# same rows in another order?
if [ "$(LC_ALL=C sort MANIFEST.tsv)" = "$(cat $exp)" ]; then
  echo "❌ the rows are right but not in byte order: sort them with LC_ALL=C so that the result does not depend on the locale"
  exit 1
fi
# find the first row that is wrong or missing
while IFS=$'\t' read -r p a b c; do
  row=$(awk -F'\t' -v p="$p" '$1==p {print; exit}' MANIFEST.tsv)
  if [ -z "$row" ]; then
    case "$p" in
      ./.*|*/.*) echo "❌ the manifest has no row for the hidden entry $p" ;;
      *) echo "❌ the manifest has no row for $p" ;;
    esac
    exit 1
  fi
  want="$p"$'\t'"$a"$'\t'"$b"${c:+$'\t'"$c"}
  if [ "$row" != "$want" ]; then
    if [ "$a" = symlink ]; then echo "❌ the row for the symlink $p is wrong: describe the link itself (its target), not the file behind it"
    else
      IFS=$'\t' read -r _ ga gb gc <<< "$row"
      if [ "$ga" != "$a" ]; then echo "❌ wrong size for $p"
      elif [ "$gb" != "$b" ]; then echo "❌ wrong mode for $p (octal permission bits, as stat -c %a prints)"
      elif [ "$gc" != "$c" ]; then echo "❌ wrong sha256 for $p (hash the file's own content)"
      else echo "❌ the row for $p has the wrong shape (tab-separated: path, size, mode, sha256)"; fi
    fi
    exit 1
  fi
done < "$exp"
echo "❌ the manifest has $(wc -l < MANIFEST.tsv) rows, expected $(wc -l < "$exp"): there are rows for directories or duplicates"
exit 1
