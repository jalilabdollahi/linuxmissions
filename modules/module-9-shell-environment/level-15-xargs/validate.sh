#!/bin/bash
# tenants/ must hold exactly one directory per real tenant line of tenants.txt
# (no comment lines, no blank lines, names kept whole), each with app.conf
# identical to template/app.conf.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f tenants.txt ] || [ "$(cksum < tenants.txt)" != "$(cat .tenants.sum 2>/dev/null)" ]; then
  echo "❌ tenants.txt was changed or removed; it is the ticket, leave it as it is (type reset)"
  exit 1
fi
if [ ! -f template/app.conf ]; then
  echo "❌ template/app.conf is missing (type reset)"
  exit 1
fi
if [ ! -d tenants ]; then
  echo "❌ the tenants/ directory is missing"
  exit 1
fi

want="$(grep -Ev '^[[:space:]]*(#|$)' tenants.txt | LC_ALL=C sort)"
got="$(ls -A tenants | LC_ALL=C sort)"

if [ -z "$got" ]; then
  echo "❌ tenants/ is still empty"
  exit 1
fi

extra="$(LC_ALL=C comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)"
if [ -n "$extra" ]; then
  case "$extra" in
    *'#'*) echo "❌ tenants/ has an entry made from a comment line: '$extra'" ;;
    *[![:space:]]*) echo "❌ tenants/ has an entry that is not a tenant name: '$extra' (was a name with a space split in two?)" ;;
    *)     echo "❌ tenants/ has an entry made from a line that only contains spaces: '$extra'" ;;
  esac
  exit 1
fi
missing="$(LC_ALL=C comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)"
if [ -n "$missing" ]; then
  n="$(LC_ALL=C comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c .)"
  echo "❌ $n tenant(s) have no directory yet, for example '$missing'"
  exit 1
fi

while IFS= read -r t; do
  if [ ! -d "tenants/$t" ]; then
    echo "❌ tenants/$t is not a directory"
    exit 1
  fi
  if [ ! -f "tenants/$t/app.conf" ]; then
    echo "❌ tenants/$t has no app.conf yet"
    exit 1
  fi
  if ! cmp -s template/app.conf "tenants/$t/app.conf"; then
    echo "❌ tenants/$t/app.conf is not identical to template/app.conf"
    exit 1
  fi
  others="$(ls -A "tenants/$t" | grep -vx 'app.conf' | head -1)"
  if [ -n "$others" ]; then
    echo "❌ tenants/$t contains '$others'; it should hold only app.conf"
    exit 1
  fi
done <<< "$want"

echo "✅ $(printf '%s\n' "$want" | grep -c .) tenants onboarded, each with the template app.conf, and nothing extra"
exit 0
