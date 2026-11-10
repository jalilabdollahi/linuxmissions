#!/bin/bash
# $1 = sandbox path
# site/, three old generations in backups/ (.3 was deleted by hand to free
# space), and Kim's untested rotate.sh draft: it shifts in ascending order
# (newer generations get overwritten) and dies under set -e on a missing file.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p site/css site/img backups
printf '<!doctype html>\n<title>Bakery Rosa</title>\n<h1>Fresh every morning</h1>\n' > site/index.html
printf 'body { font-family: Georgia, serif; }\n' > site/css/style.css
head -c 3000 /dev/urandom > site/img/croissant.jpg

# Older generations, each from an older build of the site
for g in 4 2 1; do
  echo "build-2026.11.0$((10 - g))-$RANDOM" > site/VERSION
  tar -czf "backups/site.tar.gz.$g" site
done
echo "build-2026.11.10-$RANDOM" > site/VERSION

cat > rotate.sh <<'EOF'
#!/bin/bash
# rotate.sh - keep 5 generations of the site backup (draft by Kim, untested)
set -eu
cd "$(dirname "$0")"

mv backups/site.tar.gz.1 backups/site.tar.gz.2
mv backups/site.tar.gz.2 backups/site.tar.gz.3
mv backups/site.tar.gz.3 backups/site.tar.gz.4
mv backups/site.tar.gz.4 backups/site.tar.gz.5
tar -czf backups/site.tar.gz.1 site
EOF
chmod +x rotate.sh

cat > ROTATION.txt <<'EOF'
Site backups, run by cron every night as ./rotate.sh from this directory:
  backups/site.tar.gz.1   newest (tonight's, a gzip tar of site/)
  backups/site.tar.gz.2   yesterday's
  ...
  backups/site.tar.gz.5   oldest; nothing older is kept
Each run shifts every generation one number up (the .5 drops off) and then
creates a fresh .1. Generations can be missing (someone deleted .3 last week
to free space): the others must still shift up by one, gap included, and the
script must not fail. backups/ holds nothing but these files.
EOF
