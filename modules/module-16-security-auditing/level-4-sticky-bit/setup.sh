#!/bin/bash
# Files That Vanish. srv/ holds shared folders. Which world-writable ones lack
# the sticky bit changes every run. Traps: a symlink to a vulnerable directory
# (mode lrwxrwxrwx, but find -type d does not list it and chmod would follow
# it), world-writable plain files (must not get +t), a directory with a space
# in its name, and a mode-772 directory (world-writable without o+x).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf srv .lm-state; mkdir -p srv .lm-state
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

mkdir -p "srv/uploads/team shared" srv/uploads/reports/drafts srv/uploads/archive \
         srv/web/public/tmp srv/web/public/cache srv/web/private srv/mail/spool/queue \
         srv/scratch srv/ftp/incoming srv/ftp/outgoing
# Not world-writable: left alone.
chmod 755 srv srv/web srv/web/public srv/mail
chmod 775 srv/uploads srv/ftp srv/ftp/outgoing
chmod 770 srv/web/private
chmod 2775 srv/uploads/reports
chmod 750 srv/mail/spool

# World-writable and no sticky bit: always vulnerable (772 has no o+x but is still writable).
vuln=("srv/uploads/team shared" srv/web/public/tmp srv/ftp/incoming srv/scratch)
chmod 777 "srv/uploads/team shared" srv/web/public/tmp srv/scratch
chmod 772 srv/ftp/incoming
# Already fine.
chmod 1777 srv/uploads/archive srv/mail/spool/queue
# Random: vulnerable or already sticky.
if [ $((RANDOM % 2)) = 0 ]; then chmod 777 srv/web/public/cache; vuln+=(srv/web/public/cache); else chmod 1777 srv/web/public/cache; fi
if [ $((RANDOM % 2)) = 0 ]; then chmod 777 srv/uploads/reports/drafts; vuln+=(srv/uploads/reports/drafts); else chmod 775 srv/uploads/reports/drafts; fi

# Files, some of them world-writable (a sticky bit on a file means nothing).
for f in srv/uploads/team\ shared/plan.txt srv/scratch/notes.tmp srv/web/public/index.html srv/ftp/incoming/data.csv; do
  echo "demo" > "$f"; chmod "$(pick 666 664 644 666)" "$f"
done
# A symlink to a vulnerable directory (and one to a harmless one).
ln -s ../../scratch srv/web/public/shared-scratch
ln -s ../private srv/web/public/internal

printf '%s\n' "${vuln[@]}" | LC_ALL=C sort > .lm-state/expected
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
find srv ! -type l | LC_ALL=C sort | while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(mode "$p")"; done > .lm-state/modes
find srv -type l | LC_ALL=C sort | while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(readlink "$p")"; done > .lm-state/links
