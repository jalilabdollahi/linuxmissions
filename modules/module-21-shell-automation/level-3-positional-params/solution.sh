#!/bin/bash
# Check the count first, keep the bucket quoted, and forward "$@".
cat > archive.sh <<'SCRIPT'
#!/bin/bash
# archive.sh BUCKET FILE...  - store FILEs in the archive bucket BUCKET
if [ "$#" -lt 2 ]; then
  echo "usage: $0 BUCKET FILE..." >&2
  exit 2
fi
bucket=$1
shift
echo "archiving $# file(s) to $bucket"
./tools/upload --bucket "$bucket" "$@"
SCRIPT
./archive.sh "finance archive" "reports/2026 Q3/summary final.pdf" "reports/2026 Q3/board  notes.txt"
cat upload.log
