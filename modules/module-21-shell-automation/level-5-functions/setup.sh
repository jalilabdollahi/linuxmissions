#!/bin/bash
# lib/units.sh: to_bytes hands its result back with `return` (wraps at 256)
# and assigns size/unit as globals in the caller's shell. check_upload.sh
# already uses the right calling convention: limit=$(to_bytes "$1").
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p lib uploads

cat > lib/units.sh <<'EOF'
# lib/units.sh - size helpers shared by the upload scripts. Source it:
#   source lib/units.sh
#
# to_bytes SIZE
#   Prints SIZE in bytes on stdout and returns 0. SIZE is a whole number with
#   an optional unit K, M, G or T (powers of 1024): 512 -> 512, 12K -> 12288,
#   3M -> 3145728.
#   Anything else (empty, 1.5G, 12KB, -3, abc): print nothing on stdout and
#   return 1. Never exit: the caller's shell must keep running.
#   It must not create or change any variable in the shell that calls it.

to_bytes() {
  size=${1%[KMGT]}
  unit=${1#"$size"}
  case $unit in
    K) size=$((size * 1024)) ;;
    M) size=$((size * 1024 * 1024)) ;;
    G) size=$((size * 1024 * 1024 * 1024)) ;;
    T) size=$((size * 1024 * 1024 * 1024 * 1024)) ;;
  esac
  return $size
}
EOF

cat > check_upload.sh <<'EOF'
#!/bin/bash
# check_upload.sh LIMIT FILE... - list the files bigger than LIMIT (512, 64K, 3M, ...)
source "$(dirname "$0")/lib/units.sh"

limit=$(to_bytes "$1") || { echo "check_upload: bad size: $1" >&2; exit 2; }
shift
for f in "$@"; do
  size=$(wc -c < "$f")
  size=$((size + 0))
  if [ "$size" -gt "$limit" ]; then
    echo "too big: $f ($size bytes, limit $limit)"
  fi
done
EOF
chmod +x check_upload.sh

head -c 300 /dev/zero > uploads/avatar.png
head -c 70000 /dev/zero > uploads/scan.pdf
head -c 2000 /dev/zero > uploads/notes.txt

cat > NOTES.txt <<'EOF'
Seen in the upload service:
  ./check_upload.sh 64K uploads/*      -> lists nothing, although scan.pdf is 70000 bytes
  ./check_upload.sh 1K uploads/*       -> "integer expression expected"
  source lib/units.sh; size=10; to_bytes 2K; echo "$? $size"   -> 0 2048 ?!
EOF
