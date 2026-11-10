#!/bin/bash
# Nightly cleanup that destroyed a box when CACHE_DIR was unset.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm

cat > cleanup.sh <<'EOF'
#!/bin/bash
# cleanup.sh - nightly cache cleanup for the shop app (cron, 03:15).
# Removes cache files that have not changed for more than a week.
# CACHE_DIR comes from the crontab (see crontab.txt).
find $CACHE_DIR -mtime +7 -delete
EOF
chmod +x cleanup.sh
sha256sum cleanup.sh 2>/dev/null | cut -d' ' -f1 > .lm/orig.sha || shasum -a 256 cleanup.sh | cut -d' ' -f1 > .lm/orig.sha

cat > crontab.txt <<'EOF'
# shop app, user shop
MAILTO=ops@example.com
CACHE_DIR=/var/cache/shopapp
15 3 * * * /opt/shop/cleanup.sh
EOF

cat > POSTMORTEM.txt <<'EOF'
INC-5120  web-03 lost /srv/uploads on Tuesday night

What happened: someone cleaned up crontab.txt on web-03 and dropped the line
CACHE_DIR=/var/cache/shopapp. At 03:15 cleanup.sh ran with CACHE_DIR unset, so
`find $CACHE_DIR -mtime +7 -delete` became `find -mtime +7 -delete`: it
deleted everything older than a week in the directory cron started in, which
was the app's home with the uploads.

What we need from cleanup.sh:
  * with CACHE_DIR unset, empty, or not a directory: say so on stderr, exit
    non-zero and delete nothing
  * with a good directory: delete only regular files, anywhere below it, that
    were last modified more than 7 days ago
  * never delete a file named .keep (the app needs them to hold directories)
  * never delete directories
  * file names in the cache are not trustworthy: spaces, a leading dash, even
    newlines occur
  * the cache contains symlinks (some point outside it): they must not be
    followed, and what they point to must not be touched
The test for this level builds such a cache and runs cleanup.sh on it, from
a directory that is NOT the cache, so keep CACHE_DIR as the only input.
EOF
