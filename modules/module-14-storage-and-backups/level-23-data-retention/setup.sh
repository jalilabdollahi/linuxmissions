#!/bin/bash
# data/ holds logs, PII exports, invoices and some bystander files. Ages are chosen well
# away from the policy limits (7/90 days, 30 days, 7 years). Whole-second mtimes, so that
# gzip (which stores seconds) can preserve them exactly. The expected final state and
# the expected log are written here from the decisions made per file; the pristine tree
# is saved so the validator can run retention.sh on a fresh copy.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state data/logs/web data/logs/db "data/logs/app server" data/exports data/invoices data/misc
now=$(date +%s)
: > .lm-state/expect.tsv; : > .lm-state/actions
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
rnd() { echo $(( $1 + RANDOM % ($2 - $1 + 1) )); }

mk() {  # path age-days action(keep|delete|compress) [gz]
  local p=$1 age=$2 act=$3 gz=$4 ts
  mkdir -p "$(dirname "$p")"
  ts=$((now - age * 86400 - RANDOM % 70000))
  head -c $(rnd 300 4000) /dev/urandom | base64 > "$p"
  [ -n "$gz" ] && { gzip -n "$p" && p="$p.gz"; }
  touch -d "@$ts" "$p"
  case $act in
    keep)
      printf '%s\t%s\t%s\n' "$p" "$ts" "$( [ -n "$gz" ] && gunzip -c "$p" | sha256sum | cut -d' ' -f1 || sha256sum < "$p" | cut -d' ' -f1)" >> .lm-state/expect.tsv ;;
    compress)
      printf '%s.gz\t%s\t%s\n' "$p" "$ts" "$(sha256sum < "$p" | cut -d' ' -f1)" >> .lm-state/expect.tsv
      echo "COMPRESS $p" >> .lm-state/actions ;;
    delete) echo "DELETE $p" >> .lm-state/actions ;;
  esac
}

# logs: <=7 days stay as they are, 7..90 days get compressed (already compressed ones stay), >90 days go
for n in web/access web/error db/slow-query "app server/worker"; do
  mk "data/logs/$n.log" $(rnd 0 5) keep
  mk "data/logs/$n-$(rnd 10 99).log" $(rnd 10 70) compress
  mk "data/logs/$n-old.log" $(rnd 100 400) delete
done
mk "data/logs/web/access-2026-09.log" $(rnd 20 60) compress
mk "data/logs/web/access-prev.log" $(rnd 12 80) keep gz
mk "data/logs/db/slow-query-prev.log" $(rnd 20 80) keep gz
mk "data/logs/web/access-2025.log" $(rnd 120 300) delete gz
mk "data/logs/db/slow-query-2025.log" $(rnd 120 300) delete gz
mk "data/logs/app server/worker-archive.log" $(rnd 150 500) delete gz
mk data/logs/README.txt $(rnd 200 600) keep
mk data/logs/web/access.log.1 $(rnd 200 600) keep

# PII exports: >30 days go unless on legal hold; the rest stay
mk "data/exports/pii-customers-$(rnd 100 999).csv" $(rnd 2 20) keep
mk "data/exports/pii-orders-$(rnd 100 999).csv" $(rnd 40 200) delete
mk "data/exports/pii-support tickets $(rnd 100 999).csv" $(rnd 40 200) delete
mk "data/exports/pii-newsletter-$(rnd 100 999).csv" $(rnd 40 300) delete
held1="pii-audit EU $(rnd 100 999).csv"; held2="pii-dispute-$(rnd 100 999).csv"
mk "data/exports/$held1" $(rnd 50 300) keep
mk "data/exports/$held2" $(rnd 60 300) keep
mk data/exports/sales-summary.csv $(rnd 100 500) keep
{ echo "# Legal hold register: exports listed here must not be deleted"
  echo "# one file name per line, maintained by Legal"
  echo ""
  echo "$held1"
  echo "pii-gone-already-$(rnd 100 999).csv"
  echo "$held2"; } > data/legal-hold.txt
touch -d "@$((now - 5 * 86400))" data/legal-hold.txt
printf 'data/legal-hold.txt\t%s\t%s\n' "$((now - 5 * 86400))" "$(sha256sum < data/legal-hold.txt | cut -d' ' -f1)" >> .lm-state/expect.tsv

# invoices: keep 7 years; older than that go
for y in 2026 2025 2023 2021; do mk "data/invoices/$y/inv-$y-$(rnd 100 999).pdf" $(rnd 20 1900) keep; done
mk "data/invoices/2020/inv-2020-$(rnd 100 999).pdf" $(rnd 2200 2400) keep
for y in 2017 2016 2015; do mk "data/invoices/$y/inv-$y-$(rnd 100 999).pdf" $(rnd 2750 3500) delete; done
mk "data/invoices/2015/inv-2015 corrected $(rnd 100 999).pdf" $(rnd 2750 3500) delete
mk data/misc/notes.txt $(rnd 300 900) keep
mk "data/misc/old report.log.txt" $(rnd 300 900) keep

LC_ALL=C sort -o .lm-state/expect.tsv .lm-state/expect.tsv
LC_ALL=C sort -o .lm-state/actions .lm-state/actions
tar -cf .lm-state/orig.tar data

cat > POLICY.txt <<'EOT'
Data retention policy, effective immediately (Compliance)

  logs      data/logs/**/*.log, *.log.gz
            - uncompressed logs older than 7 days are compressed with gzip
              (the .log file is replaced by .log.gz, original modification
              time kept); logs that are already .gz stay as they are
            - any log, compressed or not, older than 90 days is deleted
  PII       data/exports/pii-*.csv older than 30 days are deleted, unless the
            file name is listed in data/legal-hold.txt (a legal hold wins over
            age; lines starting with # and empty lines are not entries)
  invoices  data/invoices/**/*.pdf are kept for 7 years, then deleted
  anything else is not covered by this policy: leave it alone

Deliverable: retention.sh, which applies all of this to the data/ directory
next to the script (wherever it is started from) and appends one line per action
to retention.log next to the script:
    COMPRESS data/logs/web/access-12.log
    DELETE data/exports/pii-orders-381.csv
(path as seen from the script's folder). It must be safe to run again and
again: a second run changes nothing and logs nothing. Run it on data/ here.
EOT
