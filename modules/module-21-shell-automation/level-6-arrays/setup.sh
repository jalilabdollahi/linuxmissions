#!/bin/bash
# upload_batch.sh collects the manifest into one space-separated string and
# splits it again, so names with spaces fall apart. tools/upload logs each
# call on one line (<arg><arg>...) and refuses more than 4 files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p tools media

cat > tools/upload <<'EOF'
#!/bin/bash
# upload FILE...  - send up to 4 files to the media store in one request.
# Each call is appended to upload.log as one line: <file1><file2>...
printf '<%s>' "$@" >> upload.log
echo >> upload.log
if [ "$#" -gt 4 ]; then
  echo "upload: refused: $# files in one request (max 4)" >&2
  exit 1
fi
for f in "$@"; do
  if [ -f "$f" ]; then echo "upload: stored $f"; else echo "upload: no such file: $f" >&2; fi
done
EOF
chmod +x tools/upload

cat > upload_batch.sh <<'EOF'
#!/bin/bash
# upload_batch.sh MANIFEST - upload every file listed in MANIFEST
# (one file name per line, exactly as written; empty lines are ignored).
# The store takes at most 4 files per ./tools/upload call, so the files are
# sent in batches of 4, in manifest order. Last line: "uploaded N files".

manifest=$1
files=""
while read line; do
  files="$files $line"
done < "$manifest"

count=0
n=0
batch=""
for f in $files; do
  batch="$batch $f"
  n=$((n + 1))
  count=$((count + 1))
  if [ "$n" -eq 4 ]; then
    ./tools/upload $batch
    batch=""
    n=0
  fi
done
[ -n "$batch" ] && ./tools/upload $batch
echo "uploaded $count files"
EOF
chmod +x upload_batch.sh

cat > manifest.txt <<'EOF'
media/banner.png
media/Q3 report.pdf

media/team photo  (final).jpg
media/logo.svg


media/menu autumn.pdf
media/contract v2.docx
EOF
for f in banner.png "Q3 report.pdf" "team photo  (final).jpg" logo.svg "menu autumn.pdf" "contract v2.docx"; do
  echo "content of $f" > "media/$f"
done
