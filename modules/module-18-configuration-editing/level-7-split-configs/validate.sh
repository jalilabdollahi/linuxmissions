#!/bin/bash
# sites-available/ holds exactly the eight expected files with the exact block text.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cmp -s sites.conf .lm-state/sites.conf.orig; then
  echo "❌ sites.conf was changed or removed: split it into sites-available/ but leave the original in place"
  exit 1
fi
if [ ! -d sites-available ]; then
  echo "❌ the directory sites-available/ does not exist yet"
  exit 1
fi

trim() { sed -e '/./,$!d' "$1" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

want_names=$(cd .lm-state/expected && ls | LC_ALL=C sort)
got_names=$(cd sites-available && ls -A | LC_ALL=C sort)
if [ "$got_names" != "$want_names" ]; then
  missing=$(comm -23 <(echo "$want_names") <(echo "$got_names") | head -1)
  extra=$(comm -13 <(echo "$want_names") <(echo "$got_names") | head -1)
  if [ -n "$missing" ]; then
    echo "❌ sites-available/ has $(echo "$got_names" | grep -c .) files and is missing $missing (files are named after the first server_name, plus 00-header.conf)"
  else
    echo "❌ sites-available/ contains an unexpected file: $extra"
  fi
  exit 1
fi
for f in $want_names; do
  if ! diff -q <(trim .lm-state/expected/$f) <(trim sites-available/$f) >/dev/null; then
    if [ "$f" = 00-header.conf ]; then
      echo "❌ 00-header.conf must contain the comment lines from the top of sites.conf and nothing else"
    elif [ "$(grep -c '{' sites-available/$f)" != "$(grep -c '}' sites-available/$f)" ]; then
      echo "❌ sites-available/$f has unbalanced braces: a nested block was cut in half"
    else
      echo "❌ sites-available/$f does not hold exactly that site's server block"
    fi
    exit 1
  fi
done
echo "✅ sites.conf is split into 7 site files plus the header, each block intact"
exit 0
