#!/bin/bash
# missing.txt = accounts with a /home/... home in passwd whose directory is not in
# home/; orphans.txt = directories in home/ (hidden ones too) that are nobody's
# passwd home; and every existing /home/... home directory is mode 750.
# The files inside the homes must keep their modes (no chmod -R).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/passwd was changed; it is the evidence, so type 'reset' to get them back"
  exit 1
fi
for f in missing.txt orphans.txt; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

norm() { tr -d '\r' < "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's|/*$||' | grep -v '^$' | LC_ALL=C sort; }

# the accounts whose home is under /home, and the directory each should have
HOMES=$(awk -F: '$6 ~ /^\/home\/[^\/]+\/?$/ { h = $6; sub("^/home/", "", h); sub("/$", "", h); print $1 " " h }' etc/passwd)
DIRS=$(find home -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

WANT_MISSING=""
while read -r u h; do
  [ -d "home/$h" ] || WANT_MISSING="$WANT_MISSING$u
"
done <<< "$HOMES"
WANT_MISSING=$(printf '%s' "$WANT_MISSING" | LC_ALL=C sort)
WANT_ORPHANS=$(comm -23 <(printf '%s\n' "$DIRS") <(printf '%s\n' "$HOMES" | awk '{ print $2 }' | LC_ALL=C sort))

# 1. missing.txt
GOT=$(norm missing.txt)
if [ "$GOT" != "$WANT_MISSING" ]; then
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    printf '%s\n' "$WANT_MISSING" | grep -qxF -- "$u" && continue
    if ! printf '%s\n' "$HOMES" | awk '{ print $1 }' | grep -qxF -- "$u"; then
      echo "❌ missing.txt: '$u' is not an account with a home under /home; list account names"
    else
      echo "❌ missing.txt: $u's home directory exists"
    fi
    exit 1
  done <<< "$GOT"
  echo "❌ missing.txt lacks an account whose passwd home directory is not on disk (the home path in passwd is /home/x; the sandbox has it as home/x)"
  exit 1
fi

# 2. orphans.txt
GOT=$(norm orphans.txt)
if [ "$GOT" != "$WANT_ORPHANS" ]; then
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    printf '%s\n' "$WANT_ORPHANS" | grep -qxF -- "$d" && continue
    if [ ! -d "home/$d" ]; then
      echo "❌ orphans.txt: home/$d is not a directory on disk (or the name is mistyped)"
    elif printf '%s\n' "$HOMES" | awk '{ print $2 }' | grep -qxF -- "$d"; then
      echo "❌ orphans.txt: '$d' is the home of an account in passwd"
    else
      echo "❌ orphans.txt: '$d' is wrong"
    fi
    exit 1
  done <<< "$GOT"
  echo "❌ orphans.txt lacks a directory in home/ that no passwd entry points to (hidden directories count, and names are case-sensitive)"
  exit 1
fi

# 3. the files inside the homes keep their modes, nothing was removed
NOW=$(find home -mindepth 2 | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(stat -c %a "$f")" "$f"; done)
if [ "$NOW" != "$(cat .lm-state/inner)" ]; then
  echo "❌ something inside a home changed (a file was removed, or its mode: set the mode of the home directory itself, not of what is inside it)"
  exit 1
fi
# 4. modes of existing homes
while read -r u h; do
  [ -d "home/$h" ] || continue
  m=$(stat -c %a "home/$h")
  if [ "$m" != 750 ]; then
    echo "❌ home/$h (the home of $u) is mode $m, expected 750"
    exit 1
  fi
done <<< "$HOMES"
echo "✅ missing.txt and orphans.txt are exact and every existing home under /home is mode 750"
exit 0
