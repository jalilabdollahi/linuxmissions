#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
F=RELEASE_NOTES.md
if [ ! -s "$F" ]; then
  echo "❌ RELEASE_NOTES.md does not exist yet (or is empty)"
  exit 1
fi
if cmp -s "$F" .lm/expected.md; then
  echo "✅ RELEASE_NOTES.md matches the v2.4.0 notes"
  exit 0
fi
if [ "$(head -1 "$F")" != "# Release v2.4.0" ] || ! grep -qx '## Features' "$F" || ! grep -qx '## Fixes' "$F" || ! grep -qx '## Breaking' "$F"; then
  echo "❌ the headings do not follow RELEASE_NOTES.template (# Release v2.4.0, ## Features, ## Fixes, ## Breaking)"
  exit 1
fi
if grep -vE '^(#|- |$)' "$F" | grep -q .; then
  echo "❌ RELEASE_NOTES.md has lines that are neither headings nor '- ' entries"
  exit 1
fi
if grep -qE '^- [a-z]+(\([^)]*\))?!?: ' "$F"; then
  echo "❌ some entries still start with the commit type, like 'fix(db): ' (keep only the text after it)"
  exit 1
fi
if grep -qE '^- (Merge|Revert) ' "$F"; then
  echo "❌ merge or revert commits are listed; they do not belong in the notes"
  exit 1
fi
if grep -qFf .lm/outside.txt "$F"; then
  echo "❌ the notes contain a commit from outside the v2.3.0..v2.4.0 range"
  exit 1
fi
if grep -qF -f .lm/reverted.txt "$F"; then
  echo "❌ a change that was reverted is still listed"
  exit 1
fi
n=$(diff "$F" .lm/expected.md | grep -m1 '^[0-9]' )
if sort "$F" | diff -q - <(sort .lm/expected.md) >/dev/null; then
  echo "❌ the right lines are there but in the wrong order or sections (oldest first; a ! commit goes to Breaking only)"
  exit 1
fi
echo "❌ RELEASE_NOTES.md differs from the expected notes (diff says: ${n:-trailing whitespace or a blank line}): entries missing or extra, or the layout deviates from the template"
exit 1
