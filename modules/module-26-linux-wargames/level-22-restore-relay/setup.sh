#!/bin/bash
# Wargame 22: restore a file share to Tuesday 18:00 from GNU tar incrementals.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf backups offsite restored RUNBOOK.txt .lm
mkdir -p backups offsite .lm/live
L=.lm/live; SNAR=.lm/share.snar
rb() { head -c "$1" /dev/urandom > "$2"; }
tag() { head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# ---- Sunday: initial state
mkdir -p $L/docs $L/finance $L/photos $L/old $L/projects/alpha $L/empty-inbox
for n in plan notes draft readme; do rb $((300 + RANDOM % 900)) $L/docs/$n.txt; done
rb 90000 $L/finance/q3.xlsx; rb 40000 $L/finance/budget.xlsx
for n in 1 2 3; do rb 20000 $L/photos/img$n.jpg; done
rb 5000 $L/old/tmp.log; rb 5000 $L/old/keep-me.log
rb 8000 $L/projects/alpha/spec.md; rb 3000 $L/projects/alpha/todo.md
tar -C $L --listed-incremental=$SNAR -cf backups/share-full-2026-11-08.tar . || exit 1
sleep 1.2
# ---- Monday
rb 700 $L/docs/plan.txt; rb 500 $L/docs/mon-new.txt; rm $L/old/tmp.log
tar -C $L --listed-incremental=$SNAR -cf backups/share-inc-2026-11-09.tar . || exit 1
sleep 1.2
# ---- Tuesday until 18:00
rb 95000 $L/finance/q3.xlsx; rb 18000 $L/photos/img4.jpg; rm $L/docs/draft.txt
mv $L/projects/alpha $L/projects/alpha-final; rb 2500 $L/projects/alpha-final/changelog.md
rb 400 $L/docs/notes.txt
tar -C $L --listed-incremental=$SNAR -cf backups/share-inc-2026-11-10.tar . || exit 1
cp backups/share-inc-2026-11-10.tar .lm/tue.tar
( cd $L && { find . -mindepth 1 -type d | sort | sed 's/^/d /'; find . -type f | sort | while read -r f; do echo "f $(sha256sum < "$f" | cut -c1-64) $f"; done; } ) > .lm/expected.txt
sleep 1.2
# ---- Wednesday 09:00: ransomware, then the ad-hoc backup
for f in docs/plan.txt docs/notes.txt finance/budget.xlsx photos/img1.jpg photos/img2.jpg projects/alpha-final/spec.md; do
  rb 1000 "$L/$f.locked"; rm "$L/$f"
done
rm -f $L/finance/q3.xlsx; echo "pay up" > $L/READ_ME_NOW.txt
tar -C $L --listed-incremental=$SNAR -cf backups/share-inc-2026-11-11.tar . || exit 1

# ---- offsite copies under other names; the share's Tuesday archive is damaged
a=$(tag); b=$(tag); c=$(tag)
cp backups/share-inc-2026-11-09.tar offsite/fs-$a.bak
cp .lm/tue.tar offsite/fs-$b.bak
cp backups/share-inc-2026-11-11.tar offsite/fs-$c.bak
size=$(stat -c %s backups/share-inc-2026-11-10.tar)
head -c $((size * (45 + RANDOM % 25) / 100)) .lm/tue.tar > backups/share-inc-2026-11-10.tar
echo "$b" > .lm/good_tue_tag
touch -d '2026-11-08 18:00' backups/share-full-2026-11-08.tar
touch -d '2026-11-09 18:00' backups/share-inc-2026-11-09.tar offsite/fs-$a.bak
touch -d '2026-11-10 18:00' backups/share-inc-2026-11-10.tar
touch -d '2026-11-10 18:02' offsite/fs-$b.bak
touch -d '2026-11-11 09:00' backups/share-inc-2026-11-11.tar
touch -d '2026-11-11 09:05' offsite/fs-$c.bak
chmod -R a-w backups offsite
cat > RUNBOOK.txt <<'TXT'
File share backups (GNU tar, --listed-incremental, one snapshot chain)
  Sunday 18:00        full backup               backups/share-full-*.tar
  Mon, Tue 18:00      incremental               backups/share-inc-*.tar
  Wed 09:00           ad-hoc incremental after the alert (contains the encrypted files)
Offsite sync copies each archive under a name derived from a hash, not a date.
All archives were taken with the share's top directory as `.`.
TXT
exit 0
