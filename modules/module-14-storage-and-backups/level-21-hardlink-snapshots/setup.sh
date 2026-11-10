#!/bin/bash
# site/ is the live tree. change-day.sh simulates a day of edits (in place, so a
# hard-linked "copy" of site would change too), deletions and additions. The player
# takes snapshots/day1 before running it and snapshots/day2 after, with unchanged
# files shared between the two. The expected states are computed here by running
# the script on a scratch copy.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state site/{pages,assets/img,data,.cache} snapshots
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

for f in pages/index.html pages/about.html pages/pricing.html pages/blog-1.html pages/blog-2.html pages/blog-3.html \
         assets/site.css assets/app.js data/products.json data/prices.csv data/customers.csv .cache/index.db; do
  head -c $((4000 + RANDOM * 3)) /dev/urandom | base64 > "site/$f"
done
for i in 1 2 3 4 5 6; do head -c $((60000 + RANDOM)) /dev/urandom > "site/assets/img/photo-$i.jpg"; done
echo "User-agent: *" > site/robots.txt
chmod 640 site/data/customers.csv; chmod 755 site/assets/app.js
find site -type f -exec touch -d "2026-11-0$((1 + RANDOM % 5)) 0$((1 + RANDOM % 9)):$((10 + RANDOM % 50)):00" {} +

# pick what the day does (random, written into the script)
ch=("pages/pricing.html" "data/prices.csv" "assets/img/photo-$((1 + RANDOM % 6)).jpg")
ch+=("$(pick pages/blog-1.html pages/blog-2.html)")
del=("pages/blog-3.html" "$(pick data/customers.csv assets/img/photo-6.jpg)")
add=("pages/blog-4.html" "assets/img/photo-7.jpg")
cat > change-day.sh <<EOT
#!/bin/bash
# One day on the site: edits in place, two deletions, two new files.
cd "\$(dirname "\$0")/site" || exit 1
EOT
for f in "${ch[@]}"; do echo "echo \"edited on day 2: \$RANDOM\" >> '$f'" ; done | sed 's/\$RANDOM/'"$RANDOM"'/' >> change-day.sh
for f in "${del[@]}"; do echo "rm -f '$f'" >> change-day.sh; done
for f in "${add[@]}"; do echo "echo 'new file $RANDOM' > '$f'" >> change-day.sh; done
chmod +x change-day.sh
# in-place appends keep inode and mtime moves forward: make the mtime explicit so the state is deterministic
for f in "${ch[@]}"; do echo "touch -d '2026-11-09 08:30:00' '$f'" >> change-day.sh; done
for f in "${add[@]}"; do echo "touch -d '2026-11-09 08:31:00' '$f'" >> change-day.sh; done

state() {  # dir -> path mode mtime sha256
  ( cd "$1" && find . -type f -print0 | while IFS= read -r -d '' p; do
      printf '%s\t%s\t%s\t%s\n' "$p" "$(stat -c %a "$p")" "$(stat -c %Y "$p")" "$(sha256sum < "$p" | cut -d' ' -f1)"
    done | LC_ALL=C sort )
}
state site > .lm-state/day1.tsv
W=$(mktemp -d "$SANDBOX/.lm-state/build.XXXXXX") || exit 1
cp -a site "$W/site"; cp change-day.sh "$W/"
bash "$W/change-day.sh"
state "$W/site" > .lm-state/day2.tsv
rm -rf "$W"
find site -type f -printf '%i\n' | sort -u > .lm-state/site-inodes0

cat > TICKET.txt <<'EOT'
The nightly "full copy" of site/ is eating the backup disk. Switch to snapshots
where a file that did not change costs no extra space:

  snapshots/day1   a snapshot of site/ as it is now
  (run ./change-day.sh once: it simulates tomorrow's edits, deletions and new files)
  snapshots/day2   a snapshot of site/ after the changes

Every snapshot must look like a complete copy of the site (same contents, modes
and modification times). Files that are identical in both days must be the same
file on disk (one inode) instead of two copies; changed files must be separate.
A file deleted from site/ must not show up in day2. Editing site/ later must
never alter an existing snapshot.
EOT
