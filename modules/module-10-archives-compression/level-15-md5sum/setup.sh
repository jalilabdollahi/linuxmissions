#!/bin/bash
# $1 = sandbox path
# 400 photo files with random names: 260 distinct contents, 140 extra copies.
# Contents come in only 24 different sizes, so many files share a size
# without sharing content.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p photos .gen

UNIQUE=260
TOTAL=400

for i in $(seq 1 $UNIQUE); do
  { printf '\377\330\377\340\000\020JFIF\000'
    head -c $(( 3072 + (RANDOM % 24) * 1024 - 11 )) /dev/urandom
  } > ".gen/$i"
done

newname() {
  local n
  while :; do
    case $((RANDOM % 7)) in
      0) n=$(printf 'IMG_%04d.jpg' $((RANDOM % 10000))) ;;
      1) n=$(printf 'IMG_%04d (1).jpg' $((RANDOM % 10000))) ;;
      2) n=$(printf 'Photo 2026-%02d-%02d at %02d.%02d.%02d.jpg' $((RANDOM % 12 + 1)) $((RANDOM % 28 + 1)) $((RANDOM % 24)) $((RANDOM % 60)) $((RANDOM % 60))) ;;
      3) n=$(printf 'WhatsApp Image 2026-%02d-%02d at %02d.%02d.%02d.jpeg' $((RANDOM % 12 + 1)) $((RANDOM % 28 + 1)) $((RANDOM % 24)) $((RANDOM % 60)) $((RANDOM % 60))) ;;
      4) n=$(printf 'DSC%05d.JPG' $((RANDOM % 100000))) ;;
      5) n=$(printf 'PXL_2026%02d%02d_%06d.jpg' $((RANDOM % 12 + 1)) $((RANDOM % 28 + 1)) $((RANDOM * 30 % 1000000))) ;;
      6) n=$(printf "Mom's birthday %d.jpg" $((RANDOM % 300))) ;;
    esac
    [ -e "photos/$n" ] || break
  done
  printf '%s' "$n"
}

# Every distinct content once, then 140 copies of randomly chosen ones
for i in $(seq 1 $UNIQUE); do
  cp ".gen/$i" "photos/$(newname)"
done
for i in $(seq $((UNIQUE + 1)) $TOTAL); do
  cp ".gen/$((RANDOM % UNIQUE + 1))" "photos/$(newname)"
done
rm -rf .gen

cat > INTAKE.txt <<'EOF'
Photo intake 2026-11-10: three phones and two laptops were synced into
photos/ at once, so the same picture often arrived several times under
different names. Keep one copy of every picture in photos/ and move the
extra copies into dupes/ so the owners can double-check before we delete.
EOF
