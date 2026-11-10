#!/bin/bash
{
echo "invoice,invoice_eur,provider_eur"
awk -F, '
FILENAME=="rates.csv" && FNR>1 { n[$2]++; d[$2,n[$2]]=$1; r[$2,n[$2]]=$3; next }
FILENAME=="provider.txt" { prov[substr($0,1,9)] = substr($0,18,12) + 0; next }
FILENAME=="invoices.csv" && FNR>1 {
  rate = 1
  if ($3 != "EUR") { rate = 0; for (i = 1; i <= n[$3]; i++) if (d[$3,i] <= $2) rate = r[$3,i] }
  cents = int(int($4 * 100 + 0.5) * rate + 0.5)
  diff = cents - prov[$1]
  if (diff > 1 || diff < -1) printf "%s,%.2f,%.2f\n", $1, cents / 100, prov[$1] / 100
}' rates.csv provider.txt invoices.csv | sort
} > mismatch.csv
