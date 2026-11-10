#!/bin/bash
# $1 = sandbox path
# Every chunk must sit at sorted/<type>/chunk-NNN.<type> (zero-byte ones at
# sorted/empty/chunk-NNN), unchanged, where <type> is what its bytes really are.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

hash256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

detect() {  # the real type, from magic bytes
  local f=$1 magic
  [ -s "$f" ] || { echo empty; return; }
  magic=$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')
  case $magic in
    1f8b*)
      if gzip -dc < "$f" 2>/dev/null | tar -tf - >/dev/null 2>&1; then echo tar.gz; else echo gz; fi ;;
    425a68*) echo bz2 ;;
    fd377a585a00*) echo xz ;;
    504b0304*) echo zip ;;
    25504446*) echo pdf ;;
    89504e470d0a1a0a*) echo png ;;
    *)
      if [ "$(dd if="$f" bs=1 skip=257 count=5 2>/dev/null)" = ustar ]; then echo tar; else echo txt; fi ;;
  esac
}

if [ ! -f recovery.sha256 ] || [ "$(grep -c . recovery.sha256)" -ne 80 ]; then
  echo "❌ recovery.sha256 is missing or changed; type 'reset'"
  exit 1
fi

left=$(find recovered -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$left" -eq 80 ]; then
  echo "❌ all 80 chunks are still in recovered/"
  exit 1
fi
if [ ! -d sorted ]; then
  echo "❌ sorted/ does not exist yet"
  exit 1
fi

types=" gz bz2 xz zip tar tar.gz png pdf txt empty "
for d in sorted/*/; do
  d=${d%/}; d=${d#sorted/}
  [ "$d" = "*" ] && break
  case "$types" in
    *" $d "*) ;;
    *) echo "❌ sorted/$d/ is not one of the type folders:$types"; exit 1 ;;
  esac
done

while read -r sum id; do
  matches=$(find sorted -type f \( -name "$id" -o -name "$id.*" \) 2>/dev/null)
  count=$(printf '%s\n' "$matches" | grep -c .)
  if [ "$count" -eq 0 ]; then
    if ls recovered/"$id"* >/dev/null 2>&1; then
      echo "❌ $id is still in recovered/ ($left chunk(s) left there)"
    else
      echo "❌ $id is nowhere in sorted/ (deleted? type 'reset' to start over)"
    fi
    exit 1
  fi
  if [ "$count" -gt 1 ]; then
    echo "❌ $id is in sorted/ $count times; each chunk belongs in exactly one place"
    exit 1
  fi
  f=$matches
  dir=${f#sorted/}; dir=${dir%%/*}
  if [ "$(hash256 < "$f")" != "$sum" ]; then
    echo "❌ $f is not the chunk as carved any more (decompressed or edited?); sort the files, don't change them"
    exit 1
  fi
  real=$(detect "$f")
  if [ "$dir" != "$real" ]; then
    if [ "$dir" = empty ]; then
      echo "❌ $f is not empty"
    elif [ "$real" = empty ]; then
      echo "❌ $f is a zero-byte file; those go to sorted/empty/"
    else
      echo "❌ $f is not really $dir; check its content again"
    fi
    exit 1
  fi
  if [ "$real" = empty ]; then want="sorted/empty/$id"; else want="sorted/$real/$id.$real"; fi
  if [ "$f" != "$want" ]; then
    echo "❌ $f is in the right folder but should be named $want"
    exit 1
  fi
done < recovery.sha256

if [ "$left" -ne 0 ]; then
  echo "❌ recovered/ still has $left file(s) that aren't chunks; leave nothing behind"
  exit 1
fi
extra=$(find sorted -type f | grep -cv '/chunk-[0-9][0-9][0-9]')
if [ "$extra" -ne 0 ]; then
  echo "❌ sorted/ has $extra file(s) that aren't chunks"
  exit 1
fi
echo "✅ all 80 chunks are sorted by their real type, with the right extension"
exit 0
