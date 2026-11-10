#!/bin/bash
# Reference solution: set -u, ${PROJECT:?} for the required input, ${1:-} and
# ${DEBUG:-} for the optional ones, and the misspelled $out_dir fixed (set -u
# is what points at it: "out_dir: unbound variable").
cat > clean_build.sh <<'SCRIPT'
#!/bin/bash
# clean_build.sh [TARGET]
# Empties the build output of one project in workspace/ before a CI build.
#   PROJECT  (required, env)   the project to clean, e.g. PROJECT=shop
#   TARGET   (optional, $1)    remove only build/TARGET instead of all of build/
#   DEBUG    (optional, env)   DEBUG=1 prints what is removed, on stderr
set -u
: "${PROJECT:?PROJECT must name a project in workspace/}"
target="${1:-}"
debug="${DEBUG:-0}"

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/workspace/$PROJECT"
outdir=build

if [ "$debug" = 1 ]; then
  echo "clean_build: project $root" >&2
fi

if [ -n "$target" ]; then
  [ "$debug" = 1 ] && echo "clean_build: removing $outdir/$target" >&2
  rm -rf "$root/$outdir/$target"
else
  [ "$debug" = 1 ] && echo "clean_build: emptying $outdir/" >&2
  rm -rf "$root/$outdir/"*
fi
echo "clean_build: done"
SCRIPT
PROJECT=shop ./clean_build.sh
ls workspace/shop workspace/shop/build
