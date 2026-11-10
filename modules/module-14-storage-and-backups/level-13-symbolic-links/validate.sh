#!/bin/bash
# 1) the set of files and links is unchanged, no stray links
# 2) external links untouched; internal links are relative
# 3) after copying the tree elsewhere (cp -a) every internal link resolves to the
#    expected file inside the copy
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -d app ] || { echo "❌ app/ is gone"; exit 1; }

now_links=$(cd app && find . -type l -printf '%p\n' | LC_ALL=C sort)
if [ "$now_links" != "$(cat .lm-state/links)" ]; then
  extra=$(comm -13 .lm-state/links <(printf '%s\n' "$now_links") | head -1)
  gone=$(comm -23 .lm-state/links <(printf '%s\n' "$now_links") | head -1)
  if [ -n "$extra" ]; then
    echo "❌ there is a new link that did not exist before ($extra): ln on a link to a directory follows it unless you tell it not to"
  else
    echo "❌ the link '$gone' is gone or is no longer a symlink"
  fi
  exit 1
fi
if [ "$(cd app && find . -type f -printf '%p %s\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1)" != "$(cat .lm-state/files)" ]; then
  echo "❌ some regular files in app/ were added, removed or changed: only the links should change"
  exit 1
fi

while IFS='|' read -r l target; do
  if [ "$(readlink "app/$l")" != "$target" ]; then
    echo "❌ the external link '$l' was changed: it points outside the tree and must stay as it was"
    exit 1
  fi
done < .lm-state/external

abs=0
while IFS='|' read -r l final; do
  t=$(readlink "app/$l")
  case "$t" in /*) echo "❌ '$l' still points to an absolute path ($t): make it relative"; exit 1 ;; esac
done < .lm-state/expect

W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/elsewhere/deeper"
cp -a app "$W/elsewhere/deeper/app2"
while IFS='|' read -r l final; do
  got=$(realpath -e "$W/elsewhere/deeper/app2/$l" 2>/dev/null)
  want=$(realpath -e "$W/elsewhere/deeper/app2/$final" 2>/dev/null)
  if [ -z "$got" ]; then
    echo "❌ after moving the tree, '$l' no longer resolves to anything (target: $(readlink "app/$l"))"
    exit 1
  fi
  if [ "$got" != "$want" ]; then
    echo "❌ after moving the tree, '$l' leads to the wrong place: it should end at $final"
    exit 1
  fi
done < .lm-state/expect
echo "✅ every internal link is relative and still reaches the same target after the tree is moved; the external links are untouched"
