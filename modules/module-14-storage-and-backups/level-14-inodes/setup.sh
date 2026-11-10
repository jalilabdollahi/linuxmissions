#!/bin/bash
# web-01: writes fail with "No space left on device" while df shows 40% used.
# ./captures has df and df -i from the box. The tree under ./srv-root is a copy of
# the relevant directories: ~45,000 PHP session files in one directory (some fresh,
# most older than 24 h, plus a few old files that are not sessions), a decoy
# directory with a few very large files, and a cache with several thousand small files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state captures
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
SESS=$(pick var/lib/php/sessions var/lib/php/session srv/app/tmp/sessions)
R=srv-root
mkdir -p "$R/$SESS" "$R/var/log/archive" "$R/var/cache/thumbs/ab" "$R/var/www/html" "$R/home/deploy"

N=45000
awk -v n=$N -v s=$RANDOM 'BEGIN{srand(s); for(i=0;i<n;i++){printf "sess_"; for(j=0;j<32;j++) printf "%x", int(rand()*16); printf "\n"}}' | sort -u > .lm-state/names
total=$(wc -l < .lm-state/names)
fresh=$((3000 + RANDOM % 2000))
# fresh sessions: 1-20 hours old; expired: 25 hours to 10 days old
head -n "$fresh" .lm-state/names | sed "s#^#$R/$SESS/#" | xargs touch -d "$((1 + RANDOM % 3)) hours ago"
sed -n "$((fresh + 1)),$((fresh + 1500))p" .lm-state/names | sed "s#^#$R/$SESS/#" | xargs touch -d "19 hours ago"
sed -n "$((fresh + 1501)),$((fresh + 20000))p" .lm-state/names | sed "s#^#$R/$SESS/#" | xargs touch -d "26 hours ago"
sed -n "$((fresh + 20001)),\$p" .lm-state/names | sed "s#^#$R/$SESS/#" | xargs touch -d "$((3 + RANDOM % 7)) days ago"
# files in the same directory that are not sessions: old, but not ours to delete
for f in .htaccess lock.pid README.old; do echo "keep $f" > "$R/$SESS/$f"; touch -d "40 days ago" "$R/$SESS/$f"; done

# decoy: few files, big, so du points here
for i in 1 2 3; do head -c 8000000 /dev/urandom > "$R/var/log/archive/access-$i.log.bak"; touch -d "$((10 * i)) days ago" "$R/var/log/archive/access-$i.log.bak"; done
# a second many-files directory, smaller than the sessions directory
awk -v n=6000 'BEGIN{for(i=0;i<n;i++) printf "var/cache/thumbs/ab/t%05d.jpg\n", i}' | sed "s#^#$R/#" | xargs touch -d "3 days ago"
for f in index.php config.php style.css; do echo "<?php // $f" > "$R/var/www/html/$f"; done
echo "deploy notes" > "$R/home/deploy/notes.txt"

used=$((38 + RANDOM % 5))
cat > captures/df.txt <<EOT
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        20G  8.${RANDOM:0:1}G   12G  ${used}% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
EOT
cat > captures/df-i.txt <<EOT
Filesystem       Inodes   IUsed IFree IUse% Mounted on
/dev/vda1        1310720 1310720     0  100% /
tmpfs             502150       1 502149    1% /dev/shm
EOT
cat > TICKET.txt <<'EOT'
web-01: logins fail with "No space left on device", yet df says the disk is
less than half full (captures/df.txt, captures/df-i.txt). A copy of the box's
tree is in ./srv-root.

1. Find the directory that holds the most files (not the most bytes) and write
   its path, relative to this folder (for example srv-root/var/...), into hog.txt.
2. That directory holds PHP session files (sess_*). A session that has not been
   touched for 24 hours is expired: delete those. Fresh sessions must stay, so
   must everything else, including other files in the same directory.
EOT
( cd "$R" && find . -path "./$SESS/sess_*" -prune -o -type f -printf '%p %s %T@\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1 ) > .lm-state/others
echo "$R/$SESS" > .lm-state/hog
head -n "$fresh" .lm-state/names > .lm-state/fresh
sed -n "$((fresh + 1)),$((fresh + 1500))p" .lm-state/names >> .lm-state/fresh
LC_ALL=C sort -o .lm-state/fresh .lm-state/fresh
