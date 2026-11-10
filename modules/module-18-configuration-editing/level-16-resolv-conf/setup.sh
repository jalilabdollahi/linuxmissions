#!/bin/bash
# A host with systemd-resolved: etc/resolv.conf is a relative symlink to the stub file;
# the package's resolved.conf has everything commented out; a vendor drop-in (10-vendor)
# already sets an old DNS server and the lab.example domain. DNS= and Domains= are lists
# that accumulate across files, so the new drop-in has to reset them.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p etc/systemd/resolved.conf.d run/systemd/resolve bin .lm-state

cat > etc/systemd/resolved.conf <<'CONF'
#  This file is part of systemd.
#
# Entries in this file show the compile time defaults. Local configuration
# should be created by either modifying this file, or by creating "drop-ins" in
# the resolved.conf.d/ subdirectory.
[Resolve]
#DNS=
#FallbackDNS=
#Domains=
#DNSSEC=no
CONF
cat > etc/systemd/resolved.conf.d/10-vendor.conf <<'CONF'
# installed by the cloud image, do not remove
[Resolve]
DNS=10.0.0.2
Domains=lab.example
CONF
cp etc/systemd/resolved.conf .lm-state/resolved.conf.orig

cp "$HERE/resolved-mock.py" bin/.resolved-mock.py
for t in systemctl resolvectl; do
  printf '#!/bin/sh\nexec python3 "$(dirname "$0")/.resolved-mock.py" %s "$@"\n' "$t" > bin/$t
  chmod 755 bin/$t
done

bin/systemctl restart systemd-resolved
mkdir -p etc
ln -s ../run/systemd/resolve/stub-resolv.conf etc/resolv.conf
cat > ticket.txt <<'TXT'
NET-212  resolver change
  new DNS servers : 10.20.0.53, then 10.20.0.54 (the old 10.0.0.2 goes away)
  search domains  : corp.example first, then lab.example
  note            : "I edited /etc/resolv.conf and it was gone after the reboot" - ops
TXT
