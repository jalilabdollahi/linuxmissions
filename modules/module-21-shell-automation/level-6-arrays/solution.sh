#!/bin/bash
# Read the manifest into an array (one element per line), drop empty lines,
# and pass slices of 4 elements to upload.
cat > upload_batch.sh <<'SCRIPT'
#!/bin/bash
# upload_batch.sh MANIFEST - upload every file listed in MANIFEST in batches of 4.
mapfile -t lines < "$1"
files=()
for line in "${lines[@]}"; do
  [ -n "$line" ] && files+=("$line")
done

for ((i = 0; i < ${#files[@]}; i += 4)); do
  ./tools/upload "${files[@]:i:4}"
done
echo "uploaded ${#files[@]} files"
SCRIPT
rm -f upload.log
./upload_batch.sh manifest.txt
cat upload.log
