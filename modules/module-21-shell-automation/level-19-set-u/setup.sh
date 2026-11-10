#!/bin/bash
# Typo in rm: clean_build.sh empties a project's build/ folder before CI
# builds. A misspelled variable in its rm line expands to nothing, so the
# command removes the whole project instead. With PROJECT unset it removes
# every project. Every path starts at the script's own folder, so the damage
# stays inside the sandbox.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkproject() {
  local p="workspace/$1"
  mkdir -p "$p/src" "$p/build/tests"
  printf '/* %s main */\nint main(void) { return 0; }\n' "$1" > "$p/src/main.c"
  printf '/* %s helpers */\n' "$1" > "$p/src/util.c"
  printf '# %s\nBuild with: make\n' "$1" > "$p/README.md"
  printf 'all:\n\tcc -o build/%s src/*.c\n' "$1" > "$p/Makefile"
  printf 'ELF-%s\n' "$1" > "$p/build/$1"
  printf 'obj\n' > "$p/build/main.o"
  printf 'obj\n' > "$p/build/util.o"
  printf '<testsuite name="%s"/>\n' "$1" > "$p/build/tests/report.xml"
}
mkproject shop
mkproject billing

cat > clean_build.sh <<'SCRIPT'
#!/bin/bash
# clean_build.sh [TARGET]
# Empties the build output of one project in workspace/ before a CI build.
#   PROJECT  (required, env)   the project to clean, e.g. PROJECT=shop
#   TARGET   (optional, $1)    remove only build/TARGET instead of all of build/
#   DEBUG    (optional, env)   DEBUG=1 prints what is removed, on stderr
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/workspace/$PROJECT"
outdir=build

if [ "$DEBUG" = 1 ]; then
  echo "clean_build: project $root" >&2
fi

if [ -n "$1" ]; then
  [ "$DEBUG" = 1 ] && echo "clean_build: removing $outdir/$1" >&2
  rm -rf "$root/$outdir/$1"
else
  [ "$DEBUG" = 1 ] && echo "clean_build: emptying $outdir/" >&2
  rm -rf "$root/$out_dir/"*
fi
echo "clean_build: done"
SCRIPT
chmod +x clean_build.sh

cat > INCIDENT.txt <<'TXT'
CI job "shop", 03:12:  PROJECT=shop ./clean_build.sh
  -> workspace/shop/src, README.md and Makefile were gone afterwards,
     not only build/. Restored from backup.
CI job "nightly-all", 03:40: someone forgot PROJECT
  -> every project under workspace/ was deleted.

Careful: running the script here really deletes files in workspace/.
If that happens, type reset to get everything back.
TXT
