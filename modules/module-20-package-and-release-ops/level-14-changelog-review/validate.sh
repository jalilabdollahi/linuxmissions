#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
F=cve.env
if [ ! -s "$F" ]; then
  echo "❌ cve.env does not exist yet (or is empty)"
  exit 1
fi
want_ff=$(sed -n 's/^first_fixed=//p' .lm/expected.env)
want_p=$(sed -n 's/^patched=//p' .lm/expected.env)
ff=$(grep -E '^first_fixed=' "$F" | tail -1 | cut -d= -f2- | tr -d '[:space:]')
p=$(grep -E '^patched=' "$F" | tail -1 | cut -d= -f2- | tr -d '[:space:]')
if [ -z "$ff" ]; then
  echo "❌ cve.env has no first_fixed=<version> line"
  exit 1
fi
if [ -z "$p" ]; then
  echo "❌ cve.env has no patched=yes or patched=no line"
  exit 1
fi
if [ "$p" != yes ] && [ "$p" != no ]; then
  echo "❌ patched must be yes or no, not '$p'"
  exit 1
fi
if [ "$ff" != "$want_ff" ]; then
  if zcat libxparse/changelog.Debian.gz | grep -q "^libxparse ($ff)"; then
    echo "❌ first_fixed=$ff is a real version, but it is not the first one whose entry fixes CVE-2026-1182 (read what each entry says, and watch the exact CVE number)"
  else
    echo "❌ first_fixed=$ff is not a version that appears in the changelog"
  fi
  exit 1
fi
if [ "$p" != "$want_p" ]; then
  echo "❌ first_fixed is right, but patched=$p is wrong for the installed version (is the fix in effect there, with the later entries in mind?)"
  exit 1
fi
echo "✅ cve.env is correct: first fixed in $ff, installed copy patched=$p"
