#!/bin/bash
# $1 = sandbox path
# 80 chunks carved from a crashed upload volume. Their real types are shuffled
# on every setup, and the extensions the carver guessed are mostly wrong.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p recovered .gen

hash256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

words=(invoice shipped refund ticket backlog deploy rollback customer report draft queue mirror)
text() {  # a few random log-ish lines
  local i
  for i in $(seq 1 $((RANDOM % 30 + 5))); do
    printf '2026-11-%02d %02d:%02d %s %s #%d\n' $((RANDOM % 9 + 1)) $((RANDOM % 24)) $((RANDOM % 60)) \
      "${words[$((RANDOM % 12))]}" "${words[$((RANDOM % 12))]}" $((RANDOM % 9000 + 1000))
  done
}
treedir() {  # a small folder of text files, for tar members
  rm -rf .gen/d && mkdir -p ".gen/d/report-$1"
  text > ".gen/d/report-$1/summary.txt"
  text > ".gen/d/report-$1/details.log"
}

mkchunk() {  # mkchunk TYPE OUT
  case $1 in
    txt)    text > "$2" ;;
    gz)     text | gzip -c > "$2" ;;
    bz2)    text | bzip2 -c > "$2" ;;
    xz)     text | xz -c > "$2" ;;
    tar)    treedir "$RANDOM"; tar -cf "$2" -C .gen/d . ;;
    tar.gz) treedir "$RANDOM"; tar -czf "$2" -C .gen/d . ;;
    zip)    rm -f .gen/z.zip; text > .gen/notes.txt; ( cd .gen && zip -q z.zip notes.txt ); mv .gen/z.zip "$2" ;;
    png)    { printf '\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\100\000\000\000\060\010\002\000\000\000\152\003\161\250'
              head -c $((RANDOM % 4000 + 200)) /dev/urandom; } > "$2" ;;
    pdf)    { printf '%%PDF-1.4\n%%\342\343\317\323\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
              text; printf '%%%%EOF\n'; } > "$2" ;;
    empty)  : > "$2" ;;
  esac
}

# 80 types: how many of each, then shuffled
{
  for t in gz gz gz gz gz gz gz gz gz tar.gz tar.gz tar.gz tar.gz tar.gz tar.gz tar.gz tar.gz tar.gz \
           bz2 bz2 bz2 bz2 bz2 bz2 bz2 bz2 xz xz xz xz xz xz xz xz zip zip zip zip zip zip zip zip \
           tar tar tar tar tar tar tar tar png png png png png png png png png pdf pdf pdf pdf pdf pdf pdf pdf \
           txt txt txt txt txt txt txt txt txt txt empty empty empty; do
    echo "$RANDOM $t"
  done
} | sort -n | cut -d' ' -f2 > .gen/types

exts=("" .txt .dat .bin .zip .gz .jpg .pdf .tar.gz .png .xz)
n=0
first_gz=1
first_targz=1
: > recovery.sha256
while read -r t; do
  n=$((n + 1))
  id=$(printf 'chunk-%03d' "$n")
  ext=${exts[$((RANDOM % ${#exts[@]}))]}
  # The two classic lies: a gzip file called .txt and a tar.gz called .zip
  if [ "$t" = gz ] && [ $first_gz = 1 ]; then ext=.txt; first_gz=0; fi
  if [ "$t" = tar.gz ] && [ $first_targz = 1 ]; then ext=.zip; first_targz=0; fi
  mkchunk "$t" .gen/out
  printf '%s  %s\n' "$(hash256 < .gen/out)" "$id" >> recovery.sha256
  mv .gen/out "recovered/$id$ext"
done < .gen/types
rm -rf .gen

cat > RECOVERY-NOTES.txt <<'EOF'
photorec-style carve of /dev/vdb (upload volume, crashed 2026-11-09).
Chunks are numbered in the order they were found. The extension after the
number is only the carver's guess, and it is often wrong; some chunks have
none. recovery.sha256 has the checksum of every chunk as carved; keep it.
EOF
