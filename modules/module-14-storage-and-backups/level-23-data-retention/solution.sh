#!/bin/bash
cat > retention.sh <<'XEOF'
#!/bin/bash
# Retention policy: see POLICY.txt. Works on data/ next to this script.
cd "$(dirname "$0")" || exit 1
LOG=retention.log
log() { echo "$1 $2" >> "$LOG"; }

# logs: delete after 90 days (compressed or not), then compress what is left after 7 days
find data/logs -type f \( -name '*.log' -o -name '*.log.gz' \) -mtime +90 -print0 |
  while IFS= read -r -d '' f; do rm -f -- "$f" && log DELETE "$f"; done
find data/logs -type f -name '*.log' -mtime +7 -print0 |
  while IFS= read -r -d '' f; do gzip -- "$f" && log COMPRESS "$f"; done

# PII exports: delete after 30 days unless the exact file name is on the legal hold list
grep -vE '^[[:space:]]*(#|$)' data/legal-hold.txt > "${TMPDIR:-/tmp}/hold.$$"
find data/exports -type f -name 'pii-*.csv' -mtime +30 -print0 |
  while IFS= read -r -d '' f; do
    grep -qxF -- "${f##*/}" "${TMPDIR:-/tmp}/hold.$$" && continue
    rm -f -- "$f" && log DELETE "$f"
  done
rm -f "${TMPDIR:-/tmp}/hold.$$"

# invoices: 7 years
find data/invoices -type f -name '*.pdf' -mtime +2557 -print0 |
  while IFS= read -r -d '' f; do rm -f -- "$f" && log DELETE "$f"; done
XEOF
chmod +x retention.sh
./retention.sh
cat retention.log
