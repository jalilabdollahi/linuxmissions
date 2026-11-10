#!/bin/bash
# Every template must match the checksum of its expected version; nothing
# else may be left in templates/ (sed -i backups).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/want.sums ] || [ ! -s .lm-state/partner.count ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -d templates ]; then
  echo "❌ templates/ is gone; type 'reset'"
  exit 1
fi

extra=$(cd templates && find . -type f | sed 's|^\./||' | sort | comm -23 - <(cut -d' ' -f1 ../.lm-state/want.sums | sort) | head -1)
if [ -n "$extra" ]; then
  case "$extra" in
    *.html-E|*.html-e) echo "❌ templates/$extra is a backup that BSD sed made: there, -i takes the next argument (-E) as the backup suffix; delete it" ;;
    *.html?*) echo "❌ templates/$extra looks like a backup copy left by sed -i; delete it (only the 40 templates belong in templates/)" ;;
    *) echo "❌ templates/$extra is not one of the 40 templates; leave nothing else in templates/" ;;
  esac
  exit 1
fi

old_url='http://old-cdn\.example\.com/'
date_re='[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]'
partners=$(grep -rho 'old-cdn-example\.com' templates | wc -l | tr -d ' ')
if [ "$partners" -lt "$(cat .lm-state/partner.count)" ]; then
  echo "❌ links to the partner site old-cdn-example.com were rewritten: in a regex an unescaped . matches any character, so old-cdn.example.com also matches old-cdn-example.com"
  exit 1
fi

bad=0
while read -r path sum size; do
  f="templates/$path"
  if [ ! -f "$f" ]; then
    echo "❌ $f is missing; type 'reset' to start over"
    exit 1
  fi
  [ "$(cksum < "$f")" = "$sum $size" ] && continue
  bad=$((bad + 1))
  [ -z "$first" ] && first=$f
done < .lm-state/want.sums

if [ "$bad" -eq 0 ]; then
  echo "✅ all 40 templates point at the new CDN and use ISO dates"
  exit 0
fi

if grep -rq "$old_url" templates; then
  both=$(grep -rl "$old_url" templates | xargs grep -l 'https://cdn\.example\.net/v2/' | head -1)
  line=$(grep -rh "$old_url" templates | grep -m1 'cdn\.example\.net/v2/')
  if [ -n "$line" ]; then
    echo "❌ some lines still have an old URL after a rewritten one (e.g. in $both): without the g flag, s/// replaces only the first match on each line"
  else
    echo "❌ $(grep -rl "$old_url" templates | wc -l | tr -d ' ') template(s) still use http://old-cdn.example.com/, e.g. $(grep -rl "$old_url" templates | head -1) (did you change the files in templates/emails/ too?)"
  fi
  exit 1
fi
if grep -rq "$date_re" templates; then
  if grep -rh "$date_re" templates | grep -q '[0-9]\{4\}-[0-9][0-9]-[0-9][0-9]'; then
    echo "❌ some lines still have a DD/MM/YYYY date after a converted one: use the g flag"
  else
    echo "❌ $(grep -rl "$date_re" templates | wc -l | tr -d ' ') template(s) still have DD/MM/YYYY dates, e.g. $(grep -rl "$date_re" templates | head -1)"
  fi
  exit 1
fi
if grep -rq 'cdn\.example\.net/v2//\|cdn\.example\.net/[^v]' templates; then
  echo "❌ the new URLs are not right: http://old-cdn.example.com/css/x.css must become https://cdn.example.net/v2/css/x.css"
  exit 1
fi
echo "❌ $bad template(s) differ from the expected result, e.g. $first: check that dates are YYYY-MM-DD (year, month, day) and that nothing else changed"
exit 1
