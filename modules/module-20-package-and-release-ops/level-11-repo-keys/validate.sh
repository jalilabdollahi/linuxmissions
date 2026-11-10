#!/bin/bash
# The Acme source must carry signed-by=<a copy of the keyring that verifies the
# repository>, no trusted=yes, nothing in the global trusted keyrings, and the
# real apt update (into a scratch lists dir) must be clean.
SANDBOX="$1"
ROOT="$SANDBOX/rootfs"
export APT_CONFIG="$ROOT/etc/apt/apt.conf"
GOOD="$SANDBOX/keyrings/$(cat "$SANDBOX/.lm/good")"
URI="file:$SANDBOX/repos/acme"

if grep -rqiE 'trusted *[=:] *(yes|true)' "$ROOT/etc/apt/sources.list" "$ROOT/etc/apt/sources.list.d" 2>/dev/null; then
  echo "❌ the source is marked trusted=yes: that turns signature checking off instead of fixing the key"
  exit 1
fi
if [ -n "$(ls -A "$ROOT/etc/apt/trusted.gpg.d" 2>/dev/null)" ] || [ -e "$ROOT/etc/apt/trusted.gpg" ]; then
  echo "❌ a key was added to the system-wide trusted keyrings (trusted.gpg*): use signed-by on this one source"
  exit 1
fi
SRC=""
for f in "$ROOT/etc/apt/sources.list" "$ROOT"/etc/apt/sources.list.d/*; do
  [ -f "$f" ] && grep -q "$URI" "$f" && SRC="$f"
done
if [ -z "$SRC" ]; then
  echo "❌ no source entry for the Acme repository ($URI) is left in etc/apt"
  exit 1
fi
KR="$(grep -v '^#' "$SRC" | grep -ioE 'signed-by[=:] *[^] ]+' | head -1 | sed -E 's/^[^=:]*[=:] *//')"
if [ -z "$KR" ]; then
  echo "❌ the Acme source line has no signed-by= option yet"
  exit 1
fi
if [ ! -f "$KR" ]; then
  echo "❌ signed-by points to $KR, which is not a file (use a full path)"
  exit 1
fi
if ! cmp -s "$KR" "$GOOD"; then
  echo "❌ the keyring in signed-by does not hold the key that signed this repository (check with gpgv)"
  exit 1
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/lists/partial"
OUT="$(/usr/bin/apt-get update -o Dir::State::Lists="$TMP/lists" 2>&1)"; RC=$?
if echo "$OUT" | grep -q NO_PUBKEY; then
  echo "❌ apt update still reports NO_PUBKEY for the repository"
  exit 1
fi
if [ $RC -ne 0 ] || echo "$OUT" | grep -qE '^(W|E):'; then
  echo "❌ apt update is not clean: $(echo "$OUT" | grep -E '^(W|E):' | head -1)"
  exit 1
fi
if ! APT_CONFIG="$APT_CONFIG" /usr/bin/apt-cache policy acme-agent -o Dir::State::Lists="$TMP/lists" | grep -q 'Candidate: 3.0-1'; then
  echo "❌ apt update works but acme-agent is not offered"
  exit 1
fi
echo "✅ the Acme repository is verified by $(basename "$KR") and apt update is clean"
