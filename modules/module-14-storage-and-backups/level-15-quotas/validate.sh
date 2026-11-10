#!/bin/bash
# over.txt / hard.txt are exact sets; the mock quota database has the two new limits
# and every other value (used, limits of other users, inode limits) unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
norm() { sed 's/[[:space:]]*$//; /^$/d' "$1" | LC_ALL=C sort -u; }

for f in over hard; do
  if [ ! -s "$f.txt" ]; then echo "❌ $f.txt is missing or empty"; exit 1; fi
  got=$(norm "$f.txt"); want=$(cat ".lm-state/$f")
  if [ "$got" != "$want" ]; then
    extra=$(comm -23 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | wc -l)
    miss=$(comm -13 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | wc -l)
    echo "❌ $f.txt is not right: $extra name(s) that do not belong, $miss missing (read the flag pair, the grace column and the limits, not just the sign)"
    exit 1
  fi
done

[ -f .lm-state/quota.db ] || { echo "❌ the quota database is gone"; exit 1; }
t1=$(sed -n 1p .lm-state/target); t2=$(sed -n 2p .lm-state/target)
read -r n1 b1s b1h _ _ <<< "$t1"
read -r n2 b2s b2h i2s i2h <<< "$t2"
while read -r u bu bs bh bg iu is ih ig; do
  read -r ou obu obs obh obg oiu ois oih oig < <(grep "^$u " .lm-state/quota.orig)
  if [ "$bu" != "$obu" ] || [ "$iu" != "$oiu" ]; then echo "❌ the usage of $u changed in the database"; exit 1; fi
  case "$u" in
    "$n1") ewb="$b1s $b1h"; ewi="$ois $oih" ;;
    "$n2") ewb="$b2s $b2h"; ewi="$i2s $i2h" ;;
    *)     ewb="$obs $obh"; ewi="$ois $oih" ;;
  esac
  if [ "$bs $bh" != "$ewb" ]; then
    if [ "$u" = "$n1" ] || [ "$u" = "$n2" ]; then
      echo "❌ block limits of $u are $bs/$bh KiB, not what the ticket asks (setquota counts block limits in KiB, 1 GiB = 1048576)"
    else
      echo "❌ block limits of $u changed ($bs/$bh KiB) but the ticket does not touch $u"
    fi
    exit 1
  fi
  if [ "$is $ih" != "$ewi" ]; then
    if [ "$u" = "$n1" ]; then echo "❌ the file (inode) limits of $u changed ($is/$ih): the ticket says to leave them alone, so pass the current values"
    elif [ "$u" = "$n2" ]; then echo "❌ the file limits of $u are $is/$ih, not what the ticket asks"
    else echo "❌ file limits of $u changed but the ticket does not touch $u"; fi
    exit 1
  fi
done < .lm-state/quota.db
if [ "$(wc -l < .lm-state/quota.db)" != "$(wc -l < .lm-state/quota.orig)" ]; then echo "❌ users were added to or removed from the quota database"; exit 1; fi
echo "✅ over.txt and hard.txt are exact, and $n1 and $n2 have their new limits with nobody else touched"
