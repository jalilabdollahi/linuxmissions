#!/bin/bash
# backup/ is the tree about to be shipped: hidden files, names with spaces, odd modes,
# an empty file, symlinks (to a file, to a directory, and a dangling one) and names
# that sort differently in a language locale than in byte order. The expected
# manifest is computed here (one row per regular file: path, size, octal mode,
# sha256; one row per symlink: path, "symlink", target; byte-order sorted).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state backup
cd backup || exit 1
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
mk() {  # path mode [size]
  mkdir -p "$(dirname "$1")"
  head -c "${3:-$((200 + RANDOM % 5000))}" /dev/urandom | base64 > "$1"
  chmod "$2" "$1"
}
mk etc/app.conf 644
mk etc/db.conf 640
mk etc/Secrets.env 600
mk etc/_overrides.conf 644
mk "etc/site notes.txt" 664
mk .env 600
mk .config/app/settings.ini 644
mk .config/.cache-index 600
mk bin/deploy.sh "$(pick 755 750 775)"
mk bin/Setuid-helper 4755
mk data/orders-2026.csv 644 $((20000 + RANDOM))
mk data/Orders-2025.csv 644 $((20000 + RANDOM))
mk "data/q3 report (final).pdf" 640
mk data/a-b.txt 644
mk data/a_b.txt 644
mk data/a.b.txt 644
mk docs/README 644
mk "docs/Read Me First.txt" 664
mk docs/zeta.md 644
mk docs/Alpha.md 644
: > data/empty.log; chmod 644 data/empty.log
: > "data/zero size.dat"; chmod 600 "data/zero size.dat"
# symlinks: to a file, to a directory, dangling, with a space in the name and target
ln -s ../etc/app.conf data/app.conf.link
ln -s "../etc/site notes.txt" "docs/notes link"
ln -s ../data docs/data-dir
ln -s /var/backups/gone-away.tar "docs/old backup"
ln -s "$(pick current stable)-release" current

expected() {
  find . -type f -print0 | while IFS= read -r -d '' f; do
    printf '%s\t%s\t%s\t%s\n' "$f" "$(stat -c %s "$f")" "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -d' ' -f1)"
  done
  find . -type l -print0 | while IFS= read -r -d '' l; do
    printf '%s\tsymlink\t%s\n' "$l" "$(readlink "$l")"
  done
}
expected | LC_ALL=C sort > ../.lm-state/expect.tsv
cd ..
cat > TICKET.txt <<'EOT'
Audit wants the release set in backup/ shipped with a manifest, and the restore
team will verify against it. Write MANIFEST.tsv in this folder (not inside
backup/), tab-separated, no header:

  every regular file:  path <TAB> size in bytes <TAB> mode in octal <TAB> sha256
  every symbolic link: path <TAB> the word symlink <TAB> where it points

Paths are written the way find prints them when run inside backup/ (starting
with ./), hidden files included. Describe a symlink by its target; do not read
through it. Directories get no rows. Sort all rows in plain byte order
(LC_ALL=C), so that the file looks the same on every machine. The tree itself
must not change.
EOT
