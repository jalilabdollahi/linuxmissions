#!/bin/bash
# manifests/ must hold exactly the 14 files saved in .lm-state/docs, same content.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
docs=.lm-state/docs
[ -d manifests ] || { echo "❌ the directory manifests/ does not exist yet"; exit 1; }
want=$(ls $docs | wc -l)
have=$(ls -A manifests | wc -l)
for f in manifests/*; do
  [ -e "$f" ] || continue
  [ -s "$f" ] || { echo "❌ $f is empty"; exit 1; }
done
for f in $docs/*; do
  b=$(basename "$f")
  [ -f "manifests/$b" ] || { echo "❌ manifests/ has no file named $b ($have files present, $want expected)"; exit 1; }
done
for f in manifests/*; do
  b=$(basename "$f")
  [ -f "$docs/$b" ] || { echo "❌ $b is not one of the expected files (a leftover piece, or a wrong name)"; exit 1; }
done
for f in $docs/*; do
  b=$(basename "$f")
  if ! cmp -s "$f" "manifests/$b"; then
    if [ "$(head -1 manifests/$b)" = "---" ]; then
      echo "❌ manifests/$b still starts with the --- separator line"
    else
      echo "❌ manifests/$b does not hold exactly the lines of its document"
    fi
    exit 1
  fi
done
[ "$have" -eq "$want" ] || { echo "❌ manifests/ holds $have entries, expected $want"; exit 1; }
echo "✅ 14 manifests, correctly named and cut"
exit 0
