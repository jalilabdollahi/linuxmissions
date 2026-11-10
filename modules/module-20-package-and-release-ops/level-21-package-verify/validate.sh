#!/bin/bash
# Answers must equal the expected sets; restored files must match the original md5sums;
# conffiles must keep their edited content; nothing else may have been touched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
ROOT="$SANDBOX/rootfs"
for f in tampered.txt conffiles-changed.txt; do
  if [ ! -s "$f" ]; then
    echo "❌ $f does not exist yet (or is empty)"
    exit 1
  fi
  if grep -qvE '^/[^ ]+$' "$f"; then
    echo "❌ $f must hold absolute paths as seen inside the system (like /usr/bin/x), one per line"
    exit 1
  fi
done
sort -u conffiles-changed.txt > .lm/c.got
if ! cmp -s .lm/c.got .lm/conf.expected; then
  echo "❌ conffiles-changed.txt is not right: it must hold exactly the configuration files that differ from the package ($(wc -l < .lm/c.got) listed)"
  exit 1
fi
sort -u tampered.txt > .lm/t.got
if ! cmp -s .lm/t.got .lm/tampered.expected; then
  missing=$(comm -13 .lm/t.got .lm/tampered.expected | wc -l)
  extra=$(comm -23 .lm/t.got .lm/tampered.expected | wc -l)
  echo "❌ tampered.txt is not right: $missing altered file(s) missing, $extra listed that were not altered or are configuration files (docs count, conffiles do not)"
  exit 1
fi
md5of() { md5sum < "$ROOT$1" 2>/dev/null | cut -d' ' -f1; }
cat .lm/tampered.expected .lm/conf.expected | sort > .lm/touched
while read -r h p; do
  if grep -qxF "$p" .lm/tampered.expected; then
    if [ "$(md5of "$p")" != "$h" ]; then
      echo "❌ $p still differs from the package (restore it from the original .deb)"
      exit 1
    fi
  elif ! grep -qxF "$p" .lm/conf.expected; then
    if [ "$(md5of "$p")" != "$h" ]; then
      echo "❌ $p was not altered by the intruder but differs now: only restore the tampered files"
      exit 1
    fi
  fi
done < .lm/md5.orig
while read -r h p; do
  if [ "$(md5of "$p")" != "$h" ]; then
    echo "❌ the edited configuration file $p was changed or restored: leave admin edits alone"
    exit 1
  fi
done < .lm/conf.md5
echo "✅ tampered files restored, edited conffiles left alone, and the lists are right"
