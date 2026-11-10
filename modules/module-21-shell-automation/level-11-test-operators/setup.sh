#!/bin/bash
# needs_rebuild.sh compares `stat -c %Y` seconds with -ge, so equal mtimes
# (CI restores out/ from cache with the checkout's timestamps) always mean
# "rebuild", and a missing source silently means "up to date".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p src out

cat > needs_rebuild.sh <<'EOF'
#!/bin/bash
# needs_rebuild.sh TARGET SRC...  - decide like make does:
#   exit 0  TARGET must be rebuilt: it does not exist (a symlink that points
#           nowhere counts as not existing), or some SRC is newer than it
#   exit 1  TARGET is up to date (no SRC is newer; the same time = up to date)
#   exit 2  error, checked first, with one line on stderr:
#             fewer than 2 arguments            -> a usage line
#             a SRC that does not exist          -> "missing source: SRC"
#             a SRC that is a broken symlink     -> "broken symlink: SRC"
#             a SRC that cannot be read          -> "unreadable source: SRC"
# Nothing is ever printed on stdout.

target=$1
shift
[ -f $target ] || exit 0
t=$(stat -c %Y $target)
for src in $@; do
  s=$(stat -c %Y $src)
  if [ $s -ge $t ]; then
    exit 0
  fi
done
exit 1
EOF
chmod +x needs_rebuild.sh

cat > build.sh <<'EOF'
#!/bin/bash
# build.sh - tiny build wrapper: rebuild each target only when needed.
build() {  # build TARGET SRC...
  ./needs_rebuild.sh "$@"
  case $? in
    0) echo "rebuild     $1"; cat "${@:2}" > "$1" ;;
    1) echo "up to date  $1" ;;
    *) echo "build: cannot decide about $1, stopping" >&2; exit 2 ;;
  esac
}
build out/core.o src/core.c src/core.h
build out/net.o src/net.c src/core.h "src/tls helpers.c"
build out/app src/main.c out/core.o out/net.o
EOF
chmod +x build.sh

printf 'int core(void);\n' > src/core.h
printf '#include "core.h"\nint core(void) { return 1; }\n' > src/core.c
printf '#include "core.h"\nint net(void) { return core(); }\n' > src/net.c
printf 'int tls(void) { return 0; }\n' > "src/tls helpers.c"
printf 'int main(void) { return 0; }\n' > src/main.c
cat src/core.c src/core.h > out/core.o
cat src/net.c src/core.h "src/tls helpers.c" > out/net.o
cat src/main.c out/core.o out/net.o > out/app
# The CI cache restore gives every file the checkout's timestamp.
touch -t 202611100800.00 src/* out/*

cat > CI-NOTES.txt <<'EOF'
Every CI run recompiles everything, although out/ is restored from the cache
(same timestamps as the checkout). Locally `./build.sh` says "rebuild" for
every target too. And last week a deleted header made it say "up to date"
instead of failing. needs_rebuild.sh must decide exactly like make.
EOF
