#!/bin/bash
# big.dat was "deleted" but df did not move: the file has other names (hard links)
# scattered over the tree, one inside a dot-directory and one in a directory with
# a space. Decoys: identical-content copies with their own inode (cp), a different
# file also called big.dat, and an unrelated hard-linked pair. Names, locations and
# the number of extra links change per run (3-5). The file itself is a few MiB here.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state data archive reports shared

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

head -c $((6 * 1024 * 1024 + RANDOM * 64)) /dev/urandom > data/big.dat
echo "$(stat -c %i data/big.dat)" > .lm-state/inode

# extra names of big.dat: pick from the pool, plus one dot-directory and one with a space
slots=("exports/dump-latest.dat" "backup/2026-01/big.dat" "staging/big.dat.keep" "var-tmp/export.bin" "home/ana/Downloads/big copy.dat" "mnt-old/data/big.dat")
dots=(".cache/big.tmp" ".trash/big.dat" ".old/export.dat")
extra=("$(pick "${dots[@]}")" "scratch/job 7/big.dat")
n=$((1 + RANDOM % 3))
for k in $(seq 1 $n); do
  i=$((RANDOM % ${#slots[@]}))
  extra+=("${slots[i]}"); slots=("${slots[@]:0:i}" "${slots[@]:i+1}")
done
for e in "${extra[@]}"; do
  mkdir -p "$(dirname "$e")"
  ln data/big.dat "$e"
done

# decoys
cp data/big.dat archive/big-copy.dat
cp data/big.dat "archive/big.dat.orig"
head -c 4000000 /dev/urandom > reports/big.dat
head -c 20000 /dev/urandom | base64 > shared/a.txt
ln shared/a.txt data/a-link.txt
for d in data archive reports shared; do for f in notes-1.txt notes-2.txt; do echo "$RANDOM$RANDOM $d $f" > "$d/$f"; done; done

# everything that is not a name of big.dat must still be there afterwards
find . -path ./.lm-state -prune -o -type f ! -samefile data/big.dat -printf '%P\n' | LC_ALL=C sort | while IFS= read -r p; do
  printf '%s\t%s\n' "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
done > .lm-state/others
sha256sum < data/big.dat | cut -d' ' -f1 > .lm-state/bighash

cat > TICKET.txt <<'EOF'
The disk is 94% full. Yesterday someone deleted the 2 GB database dump
"exports/dump-latest.dat" to make room, but df did not move at all: the same
data is still referenced from other places. (Here the dump is a few MB, the
mechanics are the same.)

Remove every extra name of the dump and keep data/big.dat as its only name,
so the file ends up with a link count of 1 and nothing else is lost. Be
careful: some files merely look identical (same size, same content) but are
separate copies with their own space, and other files are linked to each other
for unrelated reasons. Leave those alone. Look in hidden directories too.
EOF
