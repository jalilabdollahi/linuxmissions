#!/bin/bash
# Strip the query string, then keep four accumulators per endpoint.
{
  printf 'endpoint\trequests\tbytes\tavg_ms\tmax_ms\n'
  awk -F'\t' 'NR > 1 {
      ep = $4; sub(/\?.*/, "", ep)
      n[ep]++; bytes[ep] += $6; ms[ep] += $7
      if ($7 > max[ep]) max[ep] = $7
    }
    END { for (ep in n) printf "%s\t%d\t%d\t%.1f\t%d\n", ep, n[ep], bytes[ep], ms[ep] / n[ep], max[ep] }' gateway.tsv \
  | sort -t "$(printf '\t')" -k2,2nr
} > stats.tsv
column -t stats.tsv
