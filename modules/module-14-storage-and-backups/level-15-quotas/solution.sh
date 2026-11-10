#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"   # as at the game prompt: the stand-in tools come first
# Part 1: the report has a blank grace column when nothing is running, so the field
# positions move; find the columns by looking at whether field 6 is a number.
cat > parse.awk <<'XEOF'
NR > 5 && NF >= 8 && $1 != "root" {
  i = 6; bg = ""
  if ($6 !~ /^[0-9]+$/) { bg = $6; i = 7 }
  iu = $i; ih = $(i+2); ig = (NF > i+2) ? $(i+3) : ""
  blocked = ($5 > 0 && $3 >= $5) || (ih > 0 && iu >= ih) || bg == "none" || ig == "none"
  over = ($2 ~ /\+/) && !blocked
  if (blocked) print $1 > "hard.txt"; else if (over) print $1 > "over.txt"
}
XEOF
repquota -a | awk -f parse.awk
# Part 2: GiB -> KiB (x 1048576); unchanged inode limits are copied from the report
lim() { repquota -a | awk -v u="$1" '$1==u {i=($6~/^[0-9]+$/)?6:7; print $(i+1), $(i+2)}'; }
while read -r u bs bh is ih; do
  [ -n "$is" ] || read -r is ih <<< "$(lim "$u")"
  setquota -u "$u" "$bs" "$bh" "$is" "$ih" /srv/nas
done < <(awk '/block limits/ {u=$1; sub(":","",u); print u, $4*1048576, $8*1048576, (NF>=16 ? $13 " " $16 : "")}' TICKET.txt)
repquota -a
