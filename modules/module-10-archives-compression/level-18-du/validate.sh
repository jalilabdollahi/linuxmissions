#!/bin/bash
# $1 = sandbox path
# The expected list is computed here, on the same filesystem, with du -sk:
# outermost cache dirs (pruned find), larger than 5120 KiB, largest first.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

for d in projects/webshop/node_modules projects/webshop/.cache projects/webshop/build \
         projects/billing-api/target projects/ml-notebooks/.cache projects/legacy-site/build \
         projects/legacy-site/node_modules projects/mobile-app/build projects/mobile-app/app/.cache; do
  if [ ! -d "$d" ]; then
    echo "❌ $d is gone; the task is to measure the caches, not delete them (type 'reset')"
    exit 1
  fi
done

if [ ! -f bloat.txt ]; then
  echo "❌ bloat.txt does not exist yet"
  exit 1
fi

expected=$(find projects -type d \( -name node_modules -o -name .cache -o -name target -o -name build \) -prune -print |
  while IFS= read -r d; do du -sk "$d"; done | awk -F'\t' '$1 > 5120' | sort -nr)
want_paths=$(printf '%s\n' "$expected" | cut -f2 | LC_ALL=C sort)

lines=$(tr -d '\r' < bloat.txt | grep -v '^[[:space:]]*$')
if [ -z "$lines" ]; then
  echo "❌ bloat.txt is empty"
  exit 1
fi
if printf '%s\n' "$lines" | grep -Eq '^[0-9.]+[KMG]'; then
  echo "❌ bloat.txt has human-readable sizes like 6.5M; write plain KiB numbers (du -k)"
  exit 1
fi
bad=$(printf '%s\n' "$lines" | grep -Ev $'^[0-9]+\t[^\t]+$' | head -1)
if [ -n "$bad" ]; then
  echo "❌ this line isn't 'KiB<TAB>path': $bad"
  exit 1
fi
norm=$(printf '%s\n' "$lines" | awk -F'\t' -v a="${SANDBOX%/}/" '
  { p = $2; if (index(p, a) == 1) p = substr(p, length(a) + 1); sub(/^\.\//, "", p); sub(/\/$/, "", p); print $1 "\t" p }')

got_paths=$(printf '%s\n' "$norm" | cut -f2 | LC_ALL=C sort)
if [ "$got_paths" != "$want_paths" ]; then
  extra=$(printf '%s\n' "$got_paths" | grep -vxF -e "$want_paths" | head -1)
  if [ -n "$extra" ]; then
    base=${extra##*/}
    case "$base" in
      node_modules|.cache|target|build) ;;
      *) echo "❌ bloat.txt lists $extra, which is not a cache dir (node_modules, .cache, target, build)"; exit 1 ;;
    esac
    if [ ! -d "$extra" ]; then
      echo "❌ bloat.txt lists $extra, which is not a directory"
    elif printf '%s\n' "${extra%/*}" | grep -Eq '/(node_modules|\.cache|target|build)(/|$)'; then
      echo "❌ bloat.txt lists $extra, which is inside another cache dir (its size is already counted there)"
    else
      echo "❌ bloat.txt lists $extra, but it is only $(du -sk "$extra" | cut -f1) KiB, not over 5 MiB (5120 KiB)"
    fi
  else
    n=$(printf '%s\n' "$want_paths" | grep -vxF -e "$got_paths" | grep -c .)
    echo "❌ bloat.txt misses $n cache dir(s) over 5 MiB (hidden ones count too)"
  fi
  exit 1
fi

while IFS=$'\t' read -r kib path; do
  real=$(du -sk "$path" | cut -f1)
  if [ "$kib" != "$real" ]; then
    echo "❌ the size for $path is $kib, but du -sk says $real KiB"
    exit 1
  fi
done <<< "$norm"

if [ "$(printf '%s\n' "$norm" | cut -f1)" != "$(printf '%s\n' "$norm" | cut -f1 | sort -nr)" ]; then
  echo "❌ the right dirs and sizes, but bloat.txt must be sorted largest first"
  exit 1
fi
echo "✅ bloat.txt lists the $(printf '%s\n' "$norm" | grep -c .) cache dirs over 5 MiB, largest first"
exit 0
