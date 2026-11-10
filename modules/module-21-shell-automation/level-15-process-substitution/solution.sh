#!/bin/bash
# Reference solution: feed comm with two process substitutions and read its
# output with `done < <(...)` so the counter lives in the main shell.
cat > stale_accounts.sh <<'SCRIPT'
#!/bin/bash
# stale_accounts.sh USERS_EXPORT HR_ROSTER
# Prints the accounts to disable, sorted, one per line, then "TOTAL n".
count=0
while read -r login; do
  echo "$login"
  count=$((count + 1))
done < <(comm -23 \
  <(awk -F: '$2 >= 1000 && $2 < 60000 { print $1 }' "$1" | sort) \
  <(awk -F, 'NR > 1 && ($3 == "active" || $3 == "leave") { print tolower($2) }' "$2" | sort -u))
echo "TOTAL $count"
SCRIPT
bash stale_accounts.sh users.export hr_roster.csv
