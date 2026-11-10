#!/bin/bash
# links.txt = every symlink under releases/, empty-dirs.txt = every empty dir.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

LINKS="releases/20261108-0912/config/app.env
releases/20261108-0912/log
releases/20261108-0912/public/uploads
releases/20261109-1544/config/app.env
releases/20261109-1544/log
releases/20261109-1544/public/uploads
releases/20261110-0230/config/app.env
releases/20261110-0230/config/app.env.next
releases/20261110-0230/node_modules
releases/current
releases/previous"
EMPTY="releases/20261108-0912/tmp
releases/20261109-1544/tmp/cache
releases/20261110-0230/public/assets/fonts
releases/20261110-0230/public/system/print queue
releases/20261110-0230/tmp/pids
releases/20261110-0230/vendor/bundle
releases/shared/node_modules"

while IFS= read -r p; do
  if [ ! -L "$p" ]; then
    echo "❌ the symlink $p is gone; type 'reset' to restore releases/"
    exit 1
  fi
done <<< "$LINKS"
while IFS= read -r p; do
  if [ ! -d "$p" ] || [ -L "$p" ]; then
    echo "❌ the directory $p is gone; type 'reset' to restore releases/"
    exit 1
  fi
done <<< "$EMPTY"

normalize() {  # file -> sorted relative paths
  tr -d '\r' < "$1" | sed -e "s|^$SANDBOX/||" -e 's|^\./||' -e 's|/$||' | grep -v '^[[:space:]]*$' | LC_ALL=C sort
}

via_link() {  # print the first symlink a path goes through (not the path itself)
  local rest=$1 prefix=""
  while [ "${rest#*/}" != "$rest" ]; do
    prefix=${prefix:+$prefix/}${rest%%/*}
    rest=${rest#*/}
    if [ -L "$prefix" ]; then echo "$prefix"; return; fi
  done
}

check() {  # file expected what
  local file=$1 want what=$3 got line
  want=$(printf '%s\n' "$2" | LC_ALL=C sort)
  if [ ! -f "$file" ]; then
    echo "❌ $file does not exist yet"
    exit 1
  fi
  got=$(normalize "$file")
  [ "$got" = "$want" ] && return 0
  if [ -n "$(printf '%s\n' "$got" | uniq -d)" ]; then
    echo "❌ $file lists a path more than once"
    exit 1
  fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\n' "$want" | grep -qxF -- "$line" && continue
    through=$(via_link "$line")
    if [ -n "$through" ]; then
      echo "❌ $file lists $line, a path inside the link $through: find followed the link; list the links themselves"
    elif [ ! -e "$line" ] && [ ! -L "$line" ]; then
      echo "❌ $file has a line that is not a path under releases/: $line"
    elif [ "$file" = links.txt ]; then
      echo "❌ links.txt lists $line, which is not a symbolic link"
    elif [ -L "$line" ]; then
      echo "❌ empty-dirs.txt lists $line, which is a symbolic link, not a directory"
    elif [ -f "$line" ] && [ ! -s "$line" ]; then
      echo "❌ empty-dirs.txt lists $line, an empty file; only empty directories belong there"
    elif [ -f "$line" ]; then
      echo "❌ empty-dirs.txt lists $line, which is a file, not a directory"
    else
      echo "❌ empty-dirs.txt lists $line, a directory that is not empty (look inside, including hidden files)"
    fi
    exit 1
  done <<< "$got"
  echo "❌ $file lists $(printf '%s\n' "$got" | grep -c .) of the $(printf '%s\n' "$want" | wc -l | tr -d ' ') $what"
  exit 1
}

check links.txt "$LINKS" "symbolic links"
check empty-dirs.txt "$EMPTY" "empty directories"
echo "✅ links.txt has all 11 symlinks (one of them dangling) and empty-dirs.txt the 7 empty directories"
exit 0
