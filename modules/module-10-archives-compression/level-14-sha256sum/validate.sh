#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

hash256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }
check256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

images="alpine-virt-3.20.3-x86_64.iso debian-12.8.0-amd64-netinst.iso ubuntu-24.04.1-live-server-amd64.iso rocky-9.4-x86_64-minimal.iso raspios-bookworm-arm64-lite.img memtest86+-7.20.iso"

if [ ! -f isos/SHA256SUMS ]; then
  echo "❌ isos/SHA256SUMS is gone; type 'reset' to get it back"
  exit 1
fi

kept=""
quarantined=0
for n in $images; do
  official=$(awk -v n="$n" '{ f = $2; sub(/^\*/, "", f) } f == n { print $1 }' isos/SHA256SUMS)
  if [ -f "isos/$n" ] && [ -f "quarantine/$n" ]; then
    echo "❌ $n is both in isos/ and in quarantine/; move it, don't copy it"
    exit 1
  elif [ -f "isos/$n" ]; then
    if [ "$(hash256 < "isos/$n")" != "$official" ]; then
      echo "❌ isos/ still holds an image whose checksum does not match SHA256SUMS"
      exit 1
    fi
    kept="$kept $n"
  elif [ -f "quarantine/$n" ]; then
    if [ "$(hash256 < "quarantine/$n")" = "$official" ]; then
      echo "❌ quarantine/$n matches SHA256SUMS; it is a good image and belongs in isos/"
      exit 1
    fi
    quarantined=$((quarantined + 1))
  else
    echo "❌ $n is missing from both isos/ and quarantine/ (the mirror notes say never delete); type 'reset'"
    exit 1
  fi
done
if [ "$quarantined" -ne 1 ]; then
  echo "❌ the damaged image should be moved into quarantine/ (next to isos/)"
  exit 1
fi
extra=$(find quarantine -type f | sed 's|^quarantine/||' | grep -vxF -e "$(printf '%s\n' $images)" | head -1)
if [ -n "$extra" ]; then
  echo "❌ quarantine/ should hold only the damaged image, but it also has $extra"
  exit 1
fi

L=isos/SHA256SUMS.local
if [ ! -f "$L" ]; then
  echo "❌ the damaged image is quarantined; now write isos/SHA256SUMS.local for the images you keep"
  exit 1
fi
listed=$(awk '{ f = $2; sub(/^\*/, "", f); sub(/^\.\//, "", f); print f }' "$L" | grep -v '^$')
if printf '%s\n' "$listed" | grep -q '^isos/'; then
  echo "❌ SHA256SUMS.local lists paths like isos/NAME; they must verify from inside isos/ (just NAME)"
  exit 1
fi
want=$(printf '%s\n' $kept | LC_ALL=C sort)
got=$(printf '%s\n' "$listed" | LC_ALL=C sort)
if [ "$got" != "$want" ]; then
  stray=$(printf '%s\n' "$listed" | grep -vxF -e "$want" | head -1)
  if [ -n "$stray" ]; then
    echo "❌ SHA256SUMS.local lists '$stray', but it should cover only the image files you keep"
  else
    echo "❌ SHA256SUMS.local lists $(printf '%s\n' "$listed" | grep -c .) files; it should cover the $(echo $kept | wc -w | tr -d ' ') images you keep"
  fi
  exit 1
fi
if ! ( cd isos && check256 -c --quiet SHA256SUMS.local >/dev/null 2>&1 ); then
  echo "❌ 'sha256sum -c SHA256SUMS.local' fails inside isos/; regenerate it from the files"
  exit 1
fi
echo "✅ the damaged image is quarantined and SHA256SUMS.local verifies the $(echo $kept | wc -w | tr -d ' ') images you serve"
exit 0
