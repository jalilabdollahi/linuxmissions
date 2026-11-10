#!/bin/bash
# hog.txt names the directory with the most files; every sess_* older than 24 h is
# gone, every younger one is still there untouched, everything else is unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
hog=$(cat .lm-state/hog)

if [ ! -s hog.txt ]; then echo "❌ hog.txt does not exist yet (or is empty): it should name the directory that holds the most files"; exit 1; fi
given=$(head -n1 hog.txt | sed 's#^\./##; s#/*$##; s#[[:space:]]*$##')
if [ "$given" != "$hog" ]; then
  echo "❌ hog.txt says '$given', but that is not the directory that holds the most files (count files, not bytes)"
  exit 1
fi
if [ ! -d "$hog" ]; then echo "❌ the sessions directory itself is gone: only expired sessions should be deleted"; exit 1; fi

now_others=$( cd srv-root && find . -path "./${hog#srv-root/}/sess_*" -prune -o -type f -printf '%p %s %T@\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1 )
if [ "$now_others" != "$(cat .lm-state/others)" ]; then
  echo "❌ something outside the session files was deleted, added or modified (other files in the directory, the cache, the logs...): only expired sess_* files may go"
  exit 1
fi
old=$(find "$hog" -maxdepth 1 -name 'sess_*' -mmin +1440 | wc -l)
if [ "$old" -gt 0 ]; then
  echo "❌ $old session files older than 24 hours are still there"
  exit 1
fi
left=$(find "$hog" -maxdepth 1 -name 'sess_*' -printf '%f\n' | LC_ALL=C sort)
if [ "$left" != "$(cat .lm-state/fresh)" ]; then
  missing=$(comm -13 <(printf '%s\n' "$left") .lm-state/fresh | wc -l)
  if [ "$missing" -gt 0 ]; then
    echo "❌ $missing sessions younger than 24 hours were deleted: those users are logged in"
  else
    echo "❌ the directory contains session files that were not there before"
  fi
  exit 1
fi
echo "✅ hog.txt names the right directory and only the expired sessions are gone ($(wc -l < .lm-state/fresh) live sessions kept)"
