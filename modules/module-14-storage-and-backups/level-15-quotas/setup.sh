#!/bin/bash
# NAS quota audit. captures/repquota-a.txt is the NAS's `repquota -a` report (made by
# the mock repquota, which keeps printing the live state). The mock setquota edits
# that state. Twelve users are assigned to roles at random:
#   two over a soft limit with grace running (one on blocks, one on INODES),
#   one at the hard block limit while grace is still running (hard wins),
#   one whose grace expired ("none"), one at the hard inode limit,
#   one with no limits at all but a huge usage, and the rest fine.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state bin captures
cp "$(dirname "$0")/quota-mock-repquota.sh" bin/repquota
cp "$(dirname "$0")/quota-mock-setquota.sh" bin/setquota
chmod +x bin/repquota bin/setquota

pool=(alice bob carol dave erin frank grace heidi ivan judy mallory nina oscar peggy trent victor wendy)
names=()
while IFS= read -r n; do names+=("$n"); done < <(printf '%s\n' "${pool[@]}" | shuf | head -12)
r() { echo $(( $1 + RANDOM % ($2 - $1 + 1) )); }

{
  echo "root 0 0 0 - 41 0 0 -"
  # roles by index: 0 over-block, 1 over-inode, 2 at hard block (grace running), 3 grace expired,
  # 4 at hard inode, 5 no limits but huge, 6..11 fine
  for i in 0 1 2 3 4 5 6 7 8 9 10 11; do
    n=${names[$i]}
    bs=$(( $(r 20 80) * 1048576 )); bh=$(( bs + $(r 5 20) * 1048576 )); is=$(r 100 400)000; ih=$(( is + $(r 20 80)000 ))
    bu=$(( bs * $(r 20 70) / 100 )); iu=$(( is * $(r 10 60) / 100 )); bg=-; ig=-
    case $i in
      0) bu=$(( bs + $(r 100000 900000) )); bg="$(r 1 6)days" ;;
      1) iu=$(( is + $(r 1000 9000) )); ig="$(r 1 6)days" ;;
      2) bu=$bh; bg="$(r 1 6)days" ;;
      3) bu=$(( bs + $(r 100000 400000) )); bg=none ;;
      4) iu=$ih; ig=none ;;
      5) bs=0; bh=0; is=0; ih=0; bu=$(( $(r 100 300) * 1048576 )) ;;
    esac
    echo "$n $bu $bs $bh $bg $iu $is $ih $ig"
  done
} > .lm-state/quota.db
bin/repquota -a > captures/repquota-a.txt

# pick the two users to raise: one (blocks only) from the fine group, one (blocks + inodes) from the at-hard-limit user
t1=${names[6]}; t2=${names[2]}
g1=$(r 60 120); g1h=$(( g1 + $(r 10 40) ))
g2=$(r 100 200); g2h=$(( g2 + $(r 10 40) ))
i2=$(r 5 9)00000; i2h=$(( i2 + 100000 ))
{
  echo "$t1 $(( g1 * 1048576 )) $(( g1h * 1048576 )) keep keep"
  echo "$t2 $(( g2 * 1048576 )) $(( g2h * 1048576 )) $i2 $i2h"
} > .lm-state/target
# expected over.txt (soft exceeded, grace running, not at hard) and hard.txt (blocked)
{ echo "${names[0]}"; echo "${names[1]}"; } | sort > .lm-state/over
{ echo "${names[2]}"; echo "${names[3]}"; echo "${names[4]}"; } | sort > .lm-state/hard
cp .lm-state/quota.db .lm-state/quota.orig

cat > TICKET.txt <<EOT
NAS /srv/nas quota audit and change request

Part 1 - from captures/repquota-a.txt (the live state: run repquota -a)
  over.txt  usernames that are over a SOFT limit (blocks or files) with the grace
            period still running, and that have not reached a hard limit.
  hard.txt  usernames that cannot write any more: at a HARD limit (blocks or files),
            or whose grace period has run out ("none").
  One name per line, any order.

Part 2 - change request CR-$(r 1000 9999)
  $t1: block limits  $g1 GiB soft / $g1h GiB hard. File (inode) limits unchanged.
  $t2: block limits  $g2 GiB soft / $g2h GiB hard, file limits $i2 soft / $i2h hard.
  Nobody else's limits change.

Use setquota (on this box it is a stand-in for the real one, same arguments:
setquota -u USER block-soft block-hard inode-soft inode-hard FILESYSTEM). The
file system is /srv/nas. Remember the units setquota takes for block limits.
EOT
