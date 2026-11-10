#!/bin/bash
# $1 = sandbox path
# The vendor bundle as extracted, plus the vendor's MANIFEST (mode, mtime, path).
# Nine entries drifted during extraction; one of them is a symlink whose own
# mtime differs (its target is fine).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

A=acme-agent
mkdir -p "$A/bin" "$A/lib/plugins" "$A/etc" "$A/share/doc" "$A/share/man" "$A/var/spool"
printf '#!/bin/sh\nexec "$(dirname "$0")/../lib/acme-agent.bin" "$@"\n' > "$A/bin/acme-agent"
printf '#!/bin/sh\necho "acme-ctl: status ok"\n' > "$A/bin/acme-ctl"
printf '#!/bin/sh\necho "helper running"\n' > "$A/bin/acme agent helper"
head -c 4096 /dev/urandom > "$A/lib/libacme.so.4.2"
ln -s libacme.so.4.2 "$A/lib/libacme.so.4"
head -c 2048 /dev/urandom > "$A/lib/plugins/http probe.so"
printf 'server = collector.acme.example\ninterval = 30\n' > "$A/etc/agent.conf"
head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$A/etc/secrets.key"
printf -- '-----BEGIN CERTIFICATE-----\nMIIBszCCAVmgAwIBAgIU\n-----END CERTIFICATE-----\n' > "$A/etc/ca bundle.pem"
printf 'acme-agent 4.2.0\n- faster uploads\n- fixes CVE-2026-1188\n' > "$A/share/doc/Release Notes.txt"
printf 'Copyright 2026 ACME Monitoring. All rights reserved.\n' > "$A/share/doc/LICENSE"
printf '.TH ACME-AGENT 8\n.SH NAME\nacme-agent \\- metrics agent\n' > "$A/share/man/acme-agent.8"
: > "$A/var/spool/.keep"
printf '#!/bin/sh\nset -e\necho "verifying bundle against MANIFEST..."\n' > "$A/install.sh"
printf '4.2.0\n' > "$A/VERSION"

# mode  path   (in MANIFEST order; directories after their content)
entries="755 $A/bin/acme-agent
755 $A/bin/acme-ctl
755 $A/bin/acme agent helper
755 $A/bin
644 $A/lib/libacme.so.4.2
777 $A/lib/libacme.so.4
644 $A/lib/plugins/http probe.so
755 $A/lib/plugins
755 $A/lib
640 $A/etc/agent.conf
600 $A/etc/secrets.key
644 $A/etc/ca bundle.pem
750 $A/etc
444 $A/share/doc/Release Notes.txt
444 $A/share/doc/LICENSE
755 $A/share/doc
644 $A/share/man/acme-agent.8
755 $A/share/man
755 $A/share
600 $A/var/spool/.keep
700 $A/var/spool
755 $A/var
755 $A/install.sh
644 $A/VERSION
755 $A"

base=$(( 1790000000 + RANDOM * 30 ))   # some day in September/October 2026
{
  echo "# acme-agent 4.2.0 bundle manifest"
  echo "# MODE  MTIME(epoch seconds)  PATH   -- the installer refuses any difference"
  printf '%s\n' "$entries" | while read -r mode path; do
    echo "$mode $(( base + RANDOM * 3 )) $path"
  done
} > MANIFEST

# Apply the manifest exactly, deepest paths first so directory times stick
grep -v '^#' MANIFEST | while read -r mode epoch path; do
  [ -L "$path" ] || chmod "$mode" "$path"
  touch -h -d "@$epoch" "$path"
done

# The drift: lost modes and extraction-time mtimes
chmod 644 "$A/bin/acme-ctl"
chmod 644 "$A/etc/secrets.key"
chmod 644 "$A/share/doc/Release Notes.txt"
chmod 755 "$A/var/spool"
for p in "$A/bin/acme agent helper" "$A/lib/libacme.so.4" "$A/lib/plugins/http probe.so" \
         "$A/VERSION" "$A/share/doc/Release Notes.txt"; do
  touch -h -d "@$(( base + 4000000 + RANDOM ))" "$p"
done
touch -h -d "@$(( base - 86400 * 3 ))" "$A/share/man/acme-agent.8"

cat > INSTALLER-ERROR.txt <<'EOF'
$ sudo ./acme-agent/install.sh
verifying bundle against MANIFEST...
ERROR: 9 entries differ from MANIFEST (mode or mtime). Refusing to install.
Hint from the vendor: the bundle must be byte-, mode- and time-exact.
EOF
