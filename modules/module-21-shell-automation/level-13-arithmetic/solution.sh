#!/bin/bash
# Reference solution: skip the header, force base 10, multiply before dividing,
# skip unlimited quotas, and divide the total once at the end.
cat > quota_report.sh <<'SCRIPT'
#!/bin/bash
# quota_report.sh USAGE_FILE
total=0
{
  read -r header
  while IFS=$'\t' read -r user used quota; do
    used=$(( 10#$used ))
    quota=$(( 10#$quota ))
    total=$(( total + used ))
    (( quota == 0 )) && continue
    pct=$(( used * 100 / quota ))
    if (( pct >= 90 )); then
      echo "$user $pct%"
    fi
  done
} < "$1"
echo "TOTAL $(( total / 1024 )) MiB"
SCRIPT
bash quota_report.sh usage.tsv
