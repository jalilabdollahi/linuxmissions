#!/bin/bash
# mirror == releases (types, symlink targets, file contents) except .local-notes,
# which keeps its files; plan.txt = exactly the *deleting lines the dry run produced.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! { [ -d mirror/.local-notes ] && find mirror/.local-notes -type f -exec sha256sum {} + 2>/dev/null | sort | cmp -s - .lm-state/notes.sums; }; then
  echo "❌ mirror/.local-notes was deleted or changed: it had to be protected from the cleanup"
  exit 1
fi
if [ -e mirror/releases ] && [ ! -e releases/releases ]; then
  echo "❌ mirror/releases exists: the source was given without a trailing slash, so rsync put the directory itself inside the mirror"
  exit 1
fi

desc() {
  (cd "$1" && find . -path ./.local-notes -prune -o \( -type l -printf '%P\tl\t%l\n' \) -o \( -type f -printf '%P\tf\t' -exec sha256sum {} \; \) -o \( -type d -printf '%P\td\t\n' \) | sed 's/  .*$//' | LC_ALL=C sort)
}
S=$(desc releases); M=$(desc mirror)
if [ "$S" != "$M" ]; then
  only_m=$(comm -13 <(printf '%s\n' "$S" | cut -f1 | sort) <(printf '%s\n' "$M" | cut -f1 | sort) | grep -c .)
  only_s=$(comm -23 <(printf '%s\n' "$S" | cut -f1 | sort) <(printf '%s\n' "$M" | cut -f1 | sort) | grep -c .)
  if [ "$only_m" -gt 0 ]; then
    echo "❌ mirror still has $only_m path(s) that no longer exist in releases/, things deleted at the source were not removed"
  elif [ "$only_s" -gt 0 ]; then
    echo "❌ $only_s path(s) of releases/ are missing from the mirror"
  else
    echo "❌ some files or links in mirror differ from releases/ (outdated content or a symlink pointing elsewhere)"
  fi
  exit 1
fi

if [ ! -f plan.txt ]; then
  echo "❌ the mirror is right, but plan.txt (the saved dry run) does not exist"
  exit 1
fi
if grep -q '\.local-notes' plan.txt; then
  echo "❌ plan.txt lists deletions inside .local-notes: the dry run you saved would have destroyed the private notes"
  exit 1
fi
if grep -qv '^\*deleting' plan.txt; then
  echo "❌ plan.txt has lines that are not '*deleting' lines: it must hold only the announced deletions"
  exit 1
fi
GOT=$(tr -d '\r' < plan.txt | sed 's/^\*deleting  *//' | awk 'NF' | LC_ALL=C sort)
if [ "$GOT" != "$(cat .lm-state/plan)" ]; then
  have=$(printf '%s\n' "$GOT" | grep -c .); want=$(grep -c . .lm-state/plan)
  if [ "$have" -lt "$want" ]; then
    echo "❌ plan.txt has $have deletion line(s), the dry run before the real run announced more (it must be saved before the mirror is changed)"
  elif [ "$have" -gt "$want" ]; then
    echo "❌ plan.txt has $have deletion lines, more than the real run carries out"
  else
    echo "❌ plan.txt names different files than the deletions the dry run announced"
  fi
  exit 1
fi
echo "✅ mirror matches releases/, the private notes survived, and plan.txt holds the $(grep -c . .lm-state/plan) announced deletions"
exit 0
