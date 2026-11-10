#!/bin/bash
# Two passes over the same file: the first collects every host's numeric
# values, END computes each host's mean and population sd and prints the
# values more than 3 sd away; sort orders the result.
head -8 requests.csv
cat > detect.sh <<'SCRIPT'
#!/bin/bash
# usage: ./detect.sh FILE   (date,host,requests with a header)
echo "host,date,value,zscore"
awk -F, 'NR > 1 && $3 ~ /^-?[0-9]+(\.[0-9]+)?$/ { n[$2]++; s[$2] += $3; k = n[$2]; v[$2, k] = $3; d[$2, k] = $1 }
  END {
    for (h in n) {
      m = s[h] / n[h]; q = 0
      for (i = 1; i <= n[h]; i++) q += (v[h, i] - m) ^ 2
      sd = sqrt(q / n[h])
      if (sd == 0) continue
      for (i = 1; i <= n[h]; i++) { z = (v[h, i] - m) / sd; if (z > 3 || z < -3) printf "%s,%s,%s,%.2f\n", h, d[h, i], v[h, i], z }
    }
  }' "$1" | sort -t, -k1,1 -k2,2
SCRIPT
chmod +x detect.sh
./detect.sh requests.csv > anomalies.csv
cat anomalies.csv
