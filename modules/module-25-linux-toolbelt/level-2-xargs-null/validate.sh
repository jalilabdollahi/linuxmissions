#!/bin/bash
# Every file listed in gone.lst must be gone, every file in keep.lst must still
# exist, and no new directory may have disappeared.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/gone.lst ]; then echo "❌ the level state is missing; type 'reset'"; exit 1; fi

left=0; lost=0; lostname=""
while IFS= read -r -d '' f; do
  [ -e "$f" ] && left=$((left + 1))
done < .lm-state/gone.lst
while IFS= read -r -d '' f; do
  if [ ! -e "$f" ]; then lost=$((lost + 1)); lostname="$f"; fi
done < .lm-state/keep.lst
total=$(tr -cd '\0' < .lm-state/gone.lst | wc -c | tr -d ' ')

if [ "$lost" -gt 0 ]; then
  echo "❌ $lost file(s) that are not thumbnails were deleted (for example: $(printf '%s' "$lostname" | head -1)); type 'reset' and be more careful"
  exit 1
fi
if [ ! -d "photos/2024/Archive 2019.thumb" ]; then
  echo "❌ a directory named *.thumb is gone: only regular files should be removed"
  exit 1
fi
if [ "$left" -gt 0 ]; then
  echo "❌ $left of the $total .thumb files are still there"
  exit 1
fi
extra=$(find photos -type f -name '*.thumb' | wc -l | tr -d ' ')
if [ "$extra" -gt 0 ]; then echo "❌ $extra .thumb file(s) are still under photos/"; exit 1; fi
echo "✅ all $total thumbnails are gone and every other file is untouched"
exit 0
