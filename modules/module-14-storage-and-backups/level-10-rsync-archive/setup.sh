#!/bin/bash
# Migrate www/ to the new server's new-server/www/ so that nothing is lost: modes
# (including setuid and sticky), times, symlinks (one dangling) and hard links.
# Names with spaces and dot files. Hard-link pairs, modes, times and the pairing
# change per run. Traps: -a does not include -H; a source without the trailing
# slash nests www/www.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state www/{bin,conf,data/archive,site/img,"site/press kit"} www/cache/empty new-server

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
rnd() { head -c $((500 + RANDOM % 4000)) /dev/urandom | base64; }

rnd > www/site/index.html
rnd > www/site/style.css
rnd > "www/site/press kit/Logo Final (v2).txt"
rnd > www/site/img/hero.txt
rnd > www/site/.htaccess
rnd > www/conf/app.ini
rnd > www/conf/secrets.env
rnd > www/data/report.csv
ln www/data/report.csv www/data/report-latest.csv
rnd > www/data/archive/2025.csv
ln www/data/archive/2025.csv www/data/archive/last-year.csv
printf '#!/bin/sh\necho tool %s\n' "$RANDOM" > www/bin/tool
ln www/bin/tool "www/bin/tool v1"
printf '#!/bin/sh\necho helper %s\n' "$RANDOM" > www/bin/helper
ln -s ../site/index.html www/data/home-link
ln -s data/archive www/archive-link
ln -s /nonexistent/old-server/path www/conf/dangling
ln -s /etc/hostname www/conf/host-ref

chmod 640 www/conf/secrets.env
chmod 600 www/conf/app.ini
chmod 750 www/bin/tool
chmod 4755 www/bin/helper
chmod 1775 www/cache
chmod 2750 www/data
chmod "$(pick 640 664 600)" www/data/report.csv
chmod 700 www/data/archive
chmod 755 www/site "www/site/press kit"

# times: random old dates on every entry, directories last
base=$(date +%s)
while IFS= read -r -d '' f; do
  [ -L "$f" ] && continue
  [ -d "$f" ] && continue
  touch -d "@$((base - 86400 * (10 + RANDOM % 600) - RANDOM))" "$f"
done < <(find www -print0)
# hard links share the inode, so they already share a time
find www -depth -type d -print0 | while IFS= read -r -d '' d; do
  touch -d "@$((base - 86400 * (10 + RANDOM % 600) - RANDOM))" "$d"
done

cat > TICKET.txt <<'EOF'
The site moves to a new server. new-server/ is the new machine's disk (empty
for now). Copy www/ to new-server/www/ so that the copy is exact: permissions
(some files are setuid, some directories sticky), modification times, symlinks
(they stay symlinks, even the dangling one) and hard links (files that share
data must still share data).

When it is done, run the same copy once more, listing what it would change
with itemized output, and save that output in second-run.txt. If the copy is
exact, the second run has nothing to do and the file is empty.
EOF
