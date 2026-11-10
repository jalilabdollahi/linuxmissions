#!/bin/bash
# Quota Report: quota_report.sh lists the users at or above 90 % of their disk
# quota and the team total. The storage export pads every number with zeros to
# 8 digits, which bash arithmetic reads as octal (or rejects), and the draft
# divides before it multiplies.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# Exported from the file server; columns are tab-separated, sizes in KiB.
printf 'user\tused_kib\tquota_kib\n' > usage.tsv
while read -r u used quota; do
  printf '%s\t%s\t%s\n' "$u" "$used" "$quota" >> usage.tsv
done <<'ROWS'
amira 00943718 01048576
bogdan 00471859 01048576
chen 02202009 02097152
dana 00524287 00524288
femi 00755000 01000000
gus 03145728 00000000
hana 00000000 00512000
ivo 00921600 01024000
jun 00460799 00512000
kofi 01009152 01048576
ROWS

cat > quota_report.sh <<'SCRIPT'
#!/bin/bash
# quota_report.sh USAGE_FILE
# Prints "user percent%" for every user at or above 90 % of their quota,
# then "TOTAL n MiB" for the whole team. A quota of 0 means unlimited.
total=0
while IFS=$'\t' read -r user used quota; do
  pct=$(( used / quota * 100 ))
  if (( pct >= 90 )); then
    echo "$user $pct%"
  fi
  total=$(( total + used / 1024 ))
done < "$1"
echo "TOTAL $total MiB"
SCRIPT
chmod +x quota_report.sh

cat > NOTE.txt <<'TXT'
From: storage team
The weekly quota mail goes out from quota_report.sh, but this week it printed
"division by 0" and "value too great for base" errors and nobody was warned.
usage.tsv: tab-separated, first line is a header, sizes in KiB, every number
zero-padded to 8 digits. A quota of 00000000 means "no limit".
Wanted output, in the order of the file:
  <user> <percent>%      for every user using at least 90 % of their quota
                         (percent = used * 100 / quota, rounded down)
  TOTAL <n> MiB          all used space added up, then divided by 1024,
                         rounded down
TXT
