#!/bin/bash
# unpack.sh: the *.gz) branch comes before *.tar.gz), so tarballs come out as
# a bare .tar (and the original disappears); .tgz names are not stripped;
# .ZIP is "unknown"; unknown types exit 0 with the message on stdout.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p inbox

cat > unpack.sh <<'EOF'
#!/bin/bash
# unpack.sh FILE - extract a vendor delivery into the CURRENT directory.
#   NAME.tar.gz  NAME.tgz  NAME.tar.xz  ->  directory NAME/ with the contents
#   NAME.zip                            ->  directory NAME/ with the contents
#   NAME.gz (one compressed file)       ->  file NAME, decompressed
# NAME is the file name without its directory and without the extension.
# Extensions may come in any letter case (the vendor's tool writes .ZIP, .TGZ).
# FILE itself is never changed or removed.
# Anything else: "unpack: unsupported file: FILE" on stderr, exit 2, and
# nothing is created.

f=$1
base=$(basename "$f")

case $base in
  *.gz)
    gunzip "$f"
    ;;
  *.tar.gz|*.tgz)
    mkdir "${base%.tar.gz}" && tar -xzf "$f" -C "${base%.tar.gz}"
    ;;
  *.tar.xz)
    mkdir "${base%.tar.xz}" && tar -xJf "$f" -C "${base%.tar.xz}"
    ;;
  *.zip)
    unzip -q "$f" -d "${base%.zip}"
    ;;
  *)
    echo "unpack: don't know how to unpack $f"
    ;;
esac
EOF
chmod +x unpack.sh

# Today's delivery from the vendor, built from a small source tree.
SRC="$(mktemp -d "$SANDBOX/.src.XXXXXX")" || exit 1
mkdir -p "$SRC/bin" "$SRC/docs"
printf '#!/bin/sh\necho report-tool 3.1\n' > "$SRC/bin/report-tool"
printf 'Report tool 3.1\n' > "$SRC/README.txt"
printf 'How to install\n' > "$SRC/docs/install guide.md"
(cd "$SRC" && tar -czf "$SANDBOX/inbox/report-tool-3.1.tar.gz" README.txt bin docs)
(cd "$SRC" && tar -czf "$SANDBOX/inbox/fonts.TGZ" docs)
(cd "$SRC" && zip -qr "$SANDBOX/inbox/Invoices Oct.ZIP" README.txt docs)
printf '10.0.0.1 - - [09/Nov/2026] "GET / HTTP/1.1" 200\n' | gzip -c > "$SANDBOX/inbox/access.log.gz"
printf 'Rar!' > "$SANDBOX/inbox/scans.rar"
rm -r -- "$SRC"

cat > SUPPORT.txt <<'EOF'
Vendor support says their deliveries are fine. Our side: unpacking
report-tool-3.1.tar.gz leaves a file report-tool-3.1.tar in inbox/ and the
.tar.gz is gone. "Invoices Oct.ZIP" is "unknown". scans.rar should fail the
job (exit 2) so someone looks at it, but the job reports success.
Try in a scratch folder:  mkdir -p try && cd try && ../unpack.sh "../inbox/Invoices Oct.ZIP"
EOF
