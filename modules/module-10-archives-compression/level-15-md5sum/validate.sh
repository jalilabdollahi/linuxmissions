#!/bin/bash
# $1 = sandbox path
# Setup made 400 files with 260 distinct contents. Solved when photos/ has one
# file per distinct content, dupes/ has the other 140, and no content was
# lost or changed (still exactly 260 distinct hashes across both folders).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
UNIQUE=260
TOTAL=400

md5list() {  # print one md5 per file found under the given dirs
  if command -v md5sum >/dev/null 2>&1; then
    find "$@" -type f -exec md5sum {} + 2>/dev/null | cut -c1-32
  else
    find "$@" -type f -exec md5 -r {} + 2>/dev/null | cut -c1-32
  fi
}

[ -d photos ] || { echo "❌ photos/ is gone; type 'reset'"; exit 1; }
dirs="photos"
[ -d dupes ] && dirs="photos dupes"

all=$(md5list $dirs)
n_all=$(printf '%s\n' "$all" | grep -c .)
if [ "$n_all" -ne "$TOTAL" ]; then
  echo "❌ photos/ and dupes/ together hold $n_all files, there were $TOTAL; move duplicates, don't delete them (type 'reset' to start over)"
  exit 1
fi
if [ "$(printf '%s\n' "$all" | sort -u | wc -l | tr -d ' ')" -ne "$UNIQUE" ]; then
  echo "❌ some file contents were changed; type 'reset' to start over"
  exit 1
fi

if [ ! -d dupes ]; then
  echo "❌ dupes/ does not exist yet"
  exit 1
fi
kept=$(md5list photos)
n_kept=$(printf '%s\n' "$kept" | grep -c .)
n_kept_uniq=$(printf '%s\n' "$kept" | grep . | sort -u | wc -l | tr -d ' ')
if [ "$n_kept_uniq" -lt "$UNIQUE" ]; then
  echo "❌ $((UNIQUE - n_kept_uniq)) picture(s) have no copy left in photos/; every distinct content must keep one copy there"
  exit 1
fi
if [ "$n_kept" -ne "$n_kept_uniq" ]; then
  echo "❌ photos/ still has $((n_kept - n_kept_uniq)) file(s) whose content is already in photos/ under another name"
  exit 1
fi
echo "✅ photos/ holds the $UNIQUE distinct pictures and dupes/ the $((TOTAL - UNIQUE)) extra copies"
exit 0
