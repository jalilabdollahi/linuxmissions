#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cksum < v1.conf 2>/dev/null)" != "2706672756 449" ] || \
   [ "$(cksum < v2.conf 2>/dev/null)" != "3295678458 454" ]; then
  echo "❌ v1.conf or v2.conf was changed; type 'reset' to restore them"
  exit 1
fi
if [ ! -s changes.diff ]; then
  echo "❌ changes.diff does not exist yet or is empty"
  exit 1
fi
if ! grep -q '^--- ' changes.diff || ! grep -q '^+++ ' changes.diff || ! grep -q '^@@ ' changes.diff; then
  echo "❌ changes.diff is not in unified format (no ---/+++ header or @@ hunks); reviewers and patch expect that format"
  exit 1
fi

# Apply the patch to a scratch copy of v1.conf and compare with v2.conf
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp v1.conf "$TMP/v1.conf"
if ! patch -s -f "$TMP/v1.conf" < changes.diff >/dev/null 2>&1; then
  echo "❌ changes.diff does not apply cleanly to v1.conf (old file first, new file second)"
  exit 1
fi
if ! cmp -s "$TMP/v1.conf" v2.conf; then
  echo "❌ applying changes.diff to v1.conf does not give v2.conf; the diff is incomplete"
  exit 1
fi
echo "✅ changes.diff is a unified diff that turns v1.conf into v2.conf"
exit 0
