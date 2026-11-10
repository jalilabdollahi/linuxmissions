#!/bin/bash
# publish.sh builds the site archive straight into releases/latest.tar.gz. A
# power cut (or kill) mid-write leaves a half-written file that the download
# servers happily serve. The validator runs publish.sh itself with a slow tar,
# kills it half-way and looks at latest.tar.gz.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state content/assets releases

for f in index.html about.html assets/app.js assets/site.css; do
  head -c $((20000 + RANDOM)) /dev/urandom | base64 > "content/$f"
done
tar -czf releases/release-old.tar.gz -C content . 2>/dev/null
cp releases/release-old.tar.gz releases/latest.tar.gz
chmod 644 releases/*.tar.gz

cat > publish.sh <<'EOF'
#!/bin/bash
# Publish the site: pack content/ into releases/latest.tar.gz.
# SRC and DEST can be overridden from the environment.
cd "$(dirname "$0")" || exit 1
SRC=${SRC:-content}
DEST=${DEST:-releases}

tar -czf "$DEST/latest.tar.gz" -C "$SRC" .
echo "published $DEST/latest.tar.gz"
EOF
chmod +x publish.sh

cat > TICKET.txt <<'EOF'
Twice this month a power cut hit the web host while publish.sh was packing the
site, and the download servers kept serving a truncated releases/latest.tar.gz
until someone noticed. Fix publish.sh so that latest.tar.gz is, at every moment,
either the complete old archive or the complete new one, and so that the new
archive is really on disk before it gets its public name.

Notes: the file stays readable by everyone (mode 644, as now). The checker
runs publish.sh with its own tar, sync and mv found through PATH, kills it in
the middle of the archive step and looks at what is left, so call those
commands by their plain names. It also sets TMPDIR to another file system.
EOF
