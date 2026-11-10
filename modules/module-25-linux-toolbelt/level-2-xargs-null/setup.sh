#!/bin/bash
# photos/ tree with ordinary names and hostile ones (space, apostrophe, newline,
# double quote, backslash). The lists of what must go and what must stay are
# kept NUL-separated in .lm-state.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state photos
: > .lm-state/gone.lst; : > .lm-state/keep.lst

add() {  # add <thumb|keep> <path>; creates the file with a few bytes
  mkdir -p "$(dirname "$2")"
  head -c $((200 + RANDOM % 900)) /dev/urandom > "$2"
  if [ "$1" = thumb ]; then printf '%s\0' "$2" >> .lm-state/gone.lst; else printf '%s\0' "$2" >> .lm-state/keep.lst; fi
}

events=(Summer Wedding Hike Birthday Graduation Roadtrip Concert Reunion)
years=(2022 2023 2024 2025)
n=0
for e in "${events[@]}"; do
  y=${years[RANDOM % 4]}
  d="photos/$y/$e"
  for i in 1 2 3; do
    n=$((n + 1))
    add keep "$d/IMG_$((1000 + RANDOM % 8000)).jpg"
    add thumb "$d/IMG_$((1000 + RANDOM % 8000)).thumb"
  done
done

# hostile names
add thumb "photos/2024/Bob's party.thumb"
add keep  "photos/2024/Bob's party.jpg"
add thumb "photos/2023/Family trip/day 1 - beach.thumb"
add keep  "photos/2023/Family trip/day 1 - beach.jpg"
add thumb "photos/2025/"'"quoted" name.thumb'
add thumb "photos/2025/back\\slash.thumb"
add thumb "photos/2022/shot
two.thumb"
add keep  "photos/2022/shot
two.jpg"
# look-alikes that must survive
add keep "photos/2022/archive.thumbs"
add keep "photos/2023/thumb"
add keep "photos/2023/old.thumb.jpg"
add keep "photos/2024/notes about .thumb files.txt"
add keep "photos/2025/.thumb.keep"
# a directory called *.thumb, holding a real photo and one thumbnail
add keep  "photos/2024/Archive 2019.thumb/DSC_0042.jpg"
add thumb "photos/2024/Archive 2019.thumb/DSC_0042.thumb"
