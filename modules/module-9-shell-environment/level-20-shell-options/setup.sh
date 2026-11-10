#!/bin/bash
# Glob Patrol: ingest.sh loops over incoming/*.csv. It chokes on an empty
# directory (processes the literal pattern), misses nested and upper-case
# files, and silently overwrites the auditors' summary.txt. The fix is shell
# options (nullglob, globstar, nocaseglob, noclobber). Needs bash 4+.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p incoming/2026-11/eu incoming/2026-11/us

csv() {  # csv FILE ROWS
  { echo "order_id,store,amount"
    for i in $(seq 1 "$2"); do echo "$(( 100000 + RANDOM )),s$(( RANDOM % 40 )),$(( RANDOM % 500 )).$(( RANDOM % 90 + 10 ))"; done
  } > "$1"
}
csv incoming/web-orders.csv $(( 5 + RANDOM % 20 ))
csv incoming/2026-11/eu/berlin.csv $(( 5 + RANDOM % 20 ))
csv incoming/2026-11/us/AUSTIN.CSV $(( 5 + RANDOM % 20 ))
csv "incoming/2026-11/store 12.Csv" $(( 5 + RANDOM % 20 ))
csv incoming/.upload-3f2a.csv 3
echo "uploads land here; see ingest.sh" > incoming/README.txt

cat > ingest.sh <<'EOF'
#!/bin/bash
# ingest.sh - load every CSV upload under incoming/ (at any depth, whether it
# ends in .csv, .CSV or .Csv) and write summary.txt.
# Hidden files (.upload-*.csv) are uploads still in progress: skip them.
# summary.txt is kept for the auditors: never overwrite an existing one.
#
# Usage: ./ingest.sh [DIR]     (DIR defaults to the directory of this script)
cd "${1:-$(dirname "$0")}" || exit 1

files=0
rows=0
for f in incoming/*.csv; do
  n=$(( $(wc -l < "$f") - 1 ))        # minus the header line
  echo "ingested $f ($n rows)"
  files=$(( files + 1 ))
  rows=$(( rows + n ))
done
echo "files=$files rows=$rows" > summary.txt
EOF
chmod +x ingest.sh
