#!/bin/bash
# archive.sh forwards its arguments with unquoted $dest and $*, so names with
# spaces are split, an empty argument vanishes and a * is globbed. The mock
# tools/upload logs its exact argv (NUL-separated) so the bug can be seen.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p tools "reports/2026 Q3"

cat > tools/upload <<'EOF'
#!/bin/bash
# upload --bucket BUCKET FILE...   (stand-in for the object-store client)
# Every call is recorded in upload.log as one block: one argument per line,
# each wrapped in <...> so spaces and empty arguments are visible.
log=${UPLOAD_LOG:-upload.log}
{
  echo "--- upload called with $# argument(s)"
  for a in "$@"; do printf '<%s>\n' "$a"; done
} >> "$log"
[ "$1" = --bucket ] && [ -n "$2" ] || { echo "upload: usage: upload --bucket BUCKET FILE..." >&2; exit 64; }
shift 2
for f in "$@"; do
  if [ -f "$f" ]; then
    echo "upload: stored $f"
  else
    echo "upload: no such file: $f" >&2
  fi
done
EOF
chmod +x tools/upload

cat > archive.sh <<'EOF'
#!/bin/bash
# archive.sh BUCKET FILE...  - store FILEs in the archive bucket BUCKET
#
# Called by the month-end job, e.g.
#   ./archive.sh "finance archive" "reports/2026 Q3/summary final.pdf" reports/ledger.csv
# Passes everything on as:  ./tools/upload --bucket BUCKET FILE...
# (one argument per file, exactly as received).
# With fewer than 2 arguments: print a usage line to stderr and exit 2.

bucket=$1
shift
echo "archiving $# file(s) to $bucket"
./tools/upload --bucket $bucket $*
EOF
chmod +x archive.sh

echo "q3 summary" > "reports/2026 Q3/summary final.pdf"
echo "date,amount" > reports/ledger.csv
echo "notes" > "reports/2026 Q3/board  notes.txt"

cat > TICKET.txt <<'EOF'
OPS-2291  month-end archive uploads the wrong things
---------------------------------------------------
The October run stored "reports/2026", "Q3/summary" and "final.pdf" in a
bucket called "finance" instead of one file in "finance archive". Board notes
with two spaces in the name never arrived at all. Check upload.log after a run.
Also: running ./archive.sh with no arguments uploaded nothing but exited 0.
EOF
