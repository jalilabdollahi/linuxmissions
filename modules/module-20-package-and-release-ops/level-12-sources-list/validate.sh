#!/bin/bash
# A scratch `apt-get update` must be clean; candidates must come from the right
# suites; the vendor repo must live in a complete deb822 .sources file only.
SANDBOX="$1"
ROOT="$SANDBOX/rootfs"
export APT_CONFIG="$ROOT/etc/apt/apt.conf"
D="$ROOT/etc/apt/sources.list.d"
VURI="file:$SANDBOX/repos/vendor"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/lists/partial"
OUT="$(/usr/bin/apt-get update -o Dir::State::Lists="$TMP/lists" 2>&1)"; RC=$?
BAD="$(echo "$OUT" | grep -E '^(W|E):' | head -1 | cut -c1-150)"
[ -z "$BAD" ] && BAD="$(echo "$OUT" | grep -E '^Err:' | head -1 | cut -c1-150)"
if [ -n "$BAD" ] || [ $RC -ne 0 ]; then
  echo "❌ apt update is not clean yet: ${BAD:-exit code $RC}"
  exit 1
fi
cand() { /usr/bin/apt-cache policy "$1" -o Dir::State::Lists="$TMP/lists" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep . || echo "(none)"; }
if [ "$(cand curl)" != "8.5.0-2" ]; then
  echo "❌ curl's candidate is $(cand curl): noble-updates is missing from the sources"
  exit 1
fi
if [ "$(cand tzdata)" != "2024b-1" ]; then
  echo "❌ tzdata's candidate is $(cand tzdata): noble-security is missing from the sources"
  exit 1
fi
if [ "$(cand acme-agent)" != "3.0-1" ]; then
  echo "❌ the vendor repository is not configured any more (acme-agent has no candidate)"
  exit 1
fi
# the vendor repo may be described only by a .sources file
for f in "$ROOT/etc/apt/sources.list" "$D"/*.list; do
  [ -f "$f" ] && grep -v '^[[:space:]]*#' "$f" | grep -q "$VURI" && {
    echo "❌ the vendor repository is still described in $(basename "$f"): move it to a .sources file and drop the old line"
    exit 1
  }
done
V=""
for f in "$D"/*.sources; do
  [ -f "$f" ] && grep -v '^[[:space:]]*#' "$f" | grep -q "$VURI" && V="$f"
done
if [ -z "$V" ]; then
  echo "❌ no .sources file describes the vendor repository ($VURI)"
  exit 1
fi
for k in Types URIs Suites Components Signed-By; do
  if ! grep -qiE "^$k:[[:space:]]*[^[:space:]]" "$V"; then
    echo "❌ $(basename "$V") has no $k: field (deb822 needs Types, URIs, Suites, Components and Signed-By)"
    exit 1
  fi
done
if ! grep -qiE '^Types:[[:space:]]*deb[[:space:]]*$' "$V"; then
  echo "❌ $(basename "$V"): Types should be 'deb'"
  exit 1
fi
SB="$(grep -iE '^Signed-By:' "$V" | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/[[:space:]]*$//')"
if [ ! -f "$SB" ] || ! cmp -s "$SB" "$ROOT/etc/apt/keyrings/vendor.gpg"; then
  echo "❌ Signed-By in $(basename "$V") is not the vendor keyring file (full path to etc/apt/keyrings/vendor.gpg)"
  exit 1
fi
echo "✅ apt update is clean, the archive is listed once per suite, and the vendor repo is a proper .sources file"
