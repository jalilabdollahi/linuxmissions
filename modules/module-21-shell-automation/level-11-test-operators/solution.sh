#!/bin/bash
# Check every source first (-L / -e / -r), then let -nt compare mtimes.
cat > needs_rebuild.sh <<'SCRIPT'
#!/bin/bash
# needs_rebuild.sh TARGET SRC...  - exit 0 rebuild, 1 up to date, 2 error
if [ "$#" -lt 2 ]; then
  echo "usage: needs_rebuild.sh TARGET SRC..." >&2
  exit 2
fi
target=$1
shift

for src in "$@"; do
  if [ -L "$src" ] && [ ! -e "$src" ]; then
    echo "broken symlink: $src" >&2; exit 2
  elif [ ! -e "$src" ]; then
    echo "missing source: $src" >&2; exit 2
  elif [ ! -r "$src" ]; then
    echo "unreadable source: $src" >&2; exit 2
  fi
done

[ -e "$target" ] || exit 0
for src in "$@"; do
  [ "$src" -nt "$target" ] && exit 0
done
exit 1
SCRIPT
./build.sh
./build.sh
