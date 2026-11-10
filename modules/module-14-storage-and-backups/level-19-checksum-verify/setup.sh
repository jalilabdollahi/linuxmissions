#!/bin/bash
# restored/ was just unpacked on the new box; MANIFEST.tsv is last night's manifest
# (path, size, octal mode, sha256 with a ./ prefix). Between the manifest and the
# restore: some files never arrived, some extra files are present (one is a renamed
# file), some are corrupted (one same-size bit flip, one truncated), two had only
# their mode changed and one only its mtime touched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state restored
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
shufn() { shuf -n "$1"; }

cd restored || exit 1
files=(
  "shop/orders/2026-10.csv" "shop/orders/2026-11.csv" "shop/orders/archive 2025.csv"
  "shop/customers.db" "shop/.htpasswd" "shop/.well-known/security.txt"
  "shop/images/logo.png" "shop/images/banner large.jpg" "shop/images/icons/cart.svg"
  "shop/images/icons/user.svg" "shop/templates/base.html" "shop/templates/cart.html"
  "shop/templates/mail/receipt.txt" "shop/static/app.js" "shop/static/app.css"
  "logs/access.log" "logs/error.log" "logs/old/access-2026-09.log.1" "conf/nginx.conf"
  "conf/sites/shop.conf" "conf/sites/staging.conf" "conf/.secrets" "README.restore"
)
for f in "${files[@]}"; do
  mkdir -p "$(dirname "$f")"
  head -c $((300 + RANDOM * 2)) /dev/urandom | base64 > "$f"
  chmod "$(pick 644 644 640 664 600)" "$f"
done
: > shop/images/empty.placeholder
manifest() {
  find . -type f -print0 | while IFS= read -r -d '' f; do
    printf '%s\t%s\t%s\t%s\n' "$f" "$(stat -c %s "$f")" "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -d' ' -f1)"
  done | LC_ALL=C sort
}
manifest > ../MANIFEST.tsv

# damage, with every victim a different file
mapfile -t order < <(printf './%s\n' "${files[@]}" | shuf)
miss=("${order[0]}" "${order[1]}" "${order[2]}")
renamed=${order[3]}
flip=${order[4]}; trunc=${order[5]}
modeonly=("${order[6]}" "${order[7]}"); touched=${order[8]}
for f in "${miss[@]}"; do rm -f "$f"; done
mv "$renamed" "$renamed.restored"
# one byte changed, same size
b=$(head -c1 "$flip" | xxd -p); n=$([ "$b" = "41" ] && echo B || echo A)
printf '%s' "$n" | dd of="$flip" bs=1 count=1 conv=notrunc status=none
truncate -s $(( $(stat -c %s "$trunc") - 7 )) "$trunc"
for f in "${modeonly[@]}"; do
  if [ "$(stat -c %a "$f")" = 600 ]; then chmod 664 "$f"; else chmod 600 "$f"; fi
done
touch -d "2020-01-01" "$touched"
printf 'junk-%s\n' $RANDOM > shop/uploads-leftover.tmp
printf 'x%s\n' $RANDOM > "logs/debug (copy).log"
cd ..
{ printf '%s\n' "${miss[@]}" "$renamed"; } | LC_ALL=C sort > .lm-state/missing
{ printf '%s\n' "$renamed.restored" ./shop/uploads-leftover.tmp "./logs/debug (copy).log"; } | LC_ALL=C sort > .lm-state/extra
{ printf '%s\n' "$flip" "$trunc"; } | LC_ALL=C sort > .lm-state/corrupt
printf '%s\n' "${modeonly[@]}" "$touched" | LC_ALL=C sort > .lm-state/noise
( cd restored && find . -type f -printf '%p %s %m %T@\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1 ) > .lm-state/tree

cat > TICKET.txt <<'EOT'
The shop was restored onto the new box (restored/). MANIFEST.tsv is the manifest
taken from last night's backup: path, size, octal mode, sha256, tab-separated,
paths starting with ./ as seen from inside restored/.

Compare the restored tree against it and write verify-report.txt with three
sections, in this order, each header on its own line followed by one path per
line (the same ./ style, byte order, no blank lines needed):

  == MISSING ==    listed in the manifest, not in the tree
  == EXTRA ==      regular files in the tree that the manifest does not list
  == CORRUPTED ==  listed and present, but the content (sha256) is different

A file whose only difference is its permissions or timestamp is not corrupted
and does not appear anywhere. A file that was renamed shows up as missing under
its old name and extra under its new one. Report only: do not change restored/.
EOT
