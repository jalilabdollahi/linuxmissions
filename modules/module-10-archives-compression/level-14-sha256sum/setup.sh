#!/bin/bash
# $1 = sandbox path
# A mirror box: SHA256SUMS lists twelve images, only six were downloaded, and
# one of the six (a random one) got damaged on the way.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p isos

hash256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

downloaded=(
  alpine-virt-3.20.3-x86_64.iso
  debian-12.8.0-amd64-netinst.iso
  ubuntu-24.04.1-live-server-amd64.iso
  rocky-9.4-x86_64-minimal.iso
  raspios-bookworm-arm64-lite.img
  memtest86+-7.20.iso
)
not_downloaded=(
  alpine-standard-3.20.3-x86_64.iso
  debian-12.8.0-amd64-DVD-1.iso
  ubuntu-24.04.1-desktop-amd64.iso
  rocky-9.4-x86_64-dvd.iso
  raspios-bookworm-arm64-full.img
  fedora-41-x86_64-netinst.iso
)

for n in "${downloaded[@]}"; do
  head -c $(( (RANDOM % 250 + 150) * 1024 + RANDOM % 1000 )) /dev/urandom > "isos/$n"
done

{
  for n in "${downloaded[@]}"; do
    printf '%s  %s\n' "$(hash256 < "isos/$n")" "$n"
  done
  for n in "${not_downloaded[@]}"; do
    printf '%s  %s\n' "$(head -c 64 /dev/urandom | hash256)" "$n"
  done
} | LC_ALL=C sort -k2 > isos/SHA256SUMS
head -c 566 /dev/urandom > isos/SHA256SUMS.gpg

# Damage one downloaded image in the middle (same size, different bytes)
bad="isos/${downloaded[$((RANDOM % 6))]}"
off=$(( $(wc -c < "$bad") / 2 + RANDOM ))
head -c 32 /dev/urandom | dd of="$bad" bs=1 seek="$off" conv=notrunc 2>/dev/null

cat > MIRROR-NOTES.txt <<'EOF'
mirror-03: images in isos/ come from SHA256SUMS of the upstream release
pages. We only pull what our installers use, so most listed images are
never downloaded. Anything that fails verification goes to quarantine/
(next to isos/) for the storage team; never delete it.
After every check, write isos/SHA256SUMS.local for exactly the images we
serve, so the nightly job can run  `cd isos && sha256sum -c SHA256SUMS.local`.
EOF
