#!/bin/bash
# Build into a temp file in the destination directory, make it 644 (mktemp
# files are 600), flush it to disk, then rename it over latest.tar.gz.
cat > publish.sh <<'EOF'
#!/bin/bash
# Publish the site: pack content/ into releases/latest.tar.gz, atomically.
# SRC and DEST can be overridden from the environment.
cd "$(dirname "$0")" || exit 1
SRC=${SRC:-content}
DEST=${DEST:-releases}

tmp=$(mktemp -p "$DEST" .latest.XXXXXX) || exit 1
trap 'rm -f "$tmp"' EXIT
tar -czf "$tmp" -C "$SRC" . || exit 1
chmod 644 "$tmp"
sync "$tmp"
mv -f "$tmp" "$DEST/latest.tar.gz"
echo "published $DEST/latest.tar.gz"
EOF
./publish.sh
ls -l releases
