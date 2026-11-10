#!/bin/bash
# The Rescue Toolkit Will Not Start. rescue/ is a minimal toolkit: the host's jq copied with
# the libraries ldd reports for it (libc, libm, loader, libjq, libonig), except ONE library
# (random: libjq or libonig) that is missing. pkgcache/ has .deb files for both library
# packages, each in a good and a decoy version (the decoy ships the previous SONAME and is
# not a usable library), and the good .deb ships only the versioned file, no SONAME link.
# Linux only: needs ldd, readelf and dpkg-deb.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
for t in ldd readelf dpkg-deb jq; do command -v $t >/dev/null || { echo "setup needs $t (Linux only level)" >&2; exit 1; }; done
JQ=$(readlink -f "$(command -v jq)")
mkdir -p .lm-state/ref pkgcache rescue/usr/bin
LDD=$(ldd "$JQ") || exit 1
LOADER=$(printf '%s\n' "$LDD" | awk '$1 ~ /^\// && $2 ~ /^\(0x/ {print $1; exit}')
[ -n "$LOADER" ] || { echo "setup: cannot find the dynamic loader in ldd output" >&2; exit 1; }
TRIPLET=$(printf '%s\n' "$LDD" | awk '$2 == "=>" && $3 ~ /libjq/ {n=split($3, a, "/"); print a[n-1]; exit}')
[ -n "$TRIPLET" ] || { echo "setup: jq does not link libjq here" >&2; exit 1; }
LIBDIR=rescue/usr/lib/$TRIPLET
mkdir -p "$LIBDIR"
cp "$JQ" rescue/usr/bin/jq
copylib() {  # copylib SONAME PATH DESTDIR  (real file + SONAME link)
  local real base
  real=$(readlink -f "$2"); base=$(basename "$real")
  cp "$real" "$3/$base"
  [ "$base" = "$1" ] || ln -sf "$base" "$3/$1"
}
printf '%s\n' "$LDD" | awk '$2 == "=>" && $3 ~ /^\// {print $1, $3}' | while read -r so path; do copylib "$so" "$path" "$LIBDIR"; done
copylib "$(basename "$LOADER")" "$LOADER" "$LIBDIR"
ln -sf "usr/lib/$TRIPLET/$(basename "$LOADER")" rescue/ld.so
# reference copies of every library (the truth the validator compares with)
for f in "$LIBDIR"/*; do [ -L "$f" ] || cp "$f" .lm-state/ref/; done
# pick the missing one
if [ $((RANDOM % 2)) -eq 0 ]; then MISS=libonig.so.5; PKG=libonig5; OTHERPKG=libjq1; OTHER=libjq.so.1
else MISS=libjq.so.1; PKG=libjq1; OTHERPKG=libonig5; OTHER=libonig.so.5; fi
echo "$MISS" > .lm-state/missing
ARCH=$(dpkg --print-architecture)
build_deb() {  # build_deb PKG VERSION SONAME-FILE-NAME SRC
  local pkg=$1 ver=$2 fname=$3 src=$4 t
  t=$(mktemp -d)
  mkdir -p "$t/DEBIAN" "$t/usr/lib/$TRIPLET" "$t/usr/share/doc/$pkg"
  cp "$src" "$t/usr/lib/$TRIPLET/$fname"
  echo "$pkg $ver" > "$t/usr/share/doc/$pkg/changelog"
  cat > "$t/DEBIAN/control" <<EOT
Package: $pkg
Version: $ver
Architecture: $ARCH
Maintainer: Rescue Toolkit Maintainers <rescue@example.org>
Section: libs
Priority: optional
Description: shared library packaged for the rescue toolkit
 Cached copy of $pkg $ver (library file only; the SONAME link is created by ldconfig).
EOT
  dpkg-deb --build --root-owner-group -Zgzip "$t" "pkgcache/${pkg}_${ver}_${ARCH}.deb" >/dev/null 2>&1 || { echo "setup: dpkg-deb failed" >&2; exit 1; }
  rm -rf "$t"
}
realname() { basename "$(readlink -f "$LIBDIR/$1")"; }   # the versioned file name of a SONAME
GOODVER=$((RANDOM % 4 + 5)).$((RANDOM % 9)).$((RANDOM % 9))-1build$((RANDOM % 3 + 1))
OLDVER=$((RANDOM % 3 + 1)).$((RANDOM % 9)).$((RANDOM % 9))-1
for spec in "$PKG:$MISS" "$OTHERPKG:$OTHER"; do
  p=${spec%%:*}; so=${spec#*:}
  rn=$(realname "$so")
  build_deb "$p" "$GOODVER" "$rn" "$LIBDIR/$rn"
  # decoy: the previous release, whose SONAME was different; its file is not this library
  old="${so%.so.*}.so.$(( ${so##*.so.} - 1 )).$((RANDOM % 9)).$((RANDOM % 9))"
  head -c 3000 /dev/urandom > .lm-state/decoy.bin; printf '\177ELF' | dd of=.lm-state/decoy.bin conv=notrunc 2>/dev/null
  build_deb "$p" "$OLDVER" "$old" .lm-state/decoy.bin
done
rm -f .lm-state/decoy.bin
# the library goes missing: SONAME link and its real file
RN=$(realname "$MISS")
rm -f "$LIBDIR/$MISS" "$LIBDIR/$RN"
cmp -s "$LIBDIR/$OTHER" ".lm-state/ref/$(realname "$OTHER")" || { echo "setup: copy of $OTHER failed" >&2; exit 1; }
cksum rescue/ld.so rescue/usr/bin/jq > .lm-state/sums
(cd "$LIBDIR" && for f in *; do [ -L "$f" ] && echo "L $f $(readlink "$f")" || cksum "$f"; done) | sort > .lm-state/libs0
echo "$TRIPLET" > .lm-state/triplet
