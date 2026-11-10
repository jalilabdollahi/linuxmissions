#!/bin/bash
# $1 = sandbox path
# release.tar.gz must hold exactly the files of app/ minus .git/, .gitignore,
# node_modules/ (any depth), *.log and files named .env, byte for byte.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

for f in app/.env app/.env.example app/logs/.keep app/.git/HEAD app/node_modules/pg/index.js app/services/worker/.env; do
  if [ ! -e "$f" ]; then
    echo "❌ $f was removed from app/; leave the source tree alone and exclude it in the archive (type 'reset')"
    exit 1
  fi
done
if [ ! -f release.tar.gz ]; then
  echo "❌ release.tar.gz does not exist yet"
  exit 1
fi
if ! gzip -t release.tar.gz 2>/dev/null; then
  echo "❌ release.tar.gz is not gzip-compressed (tar needs -z)"
  exit 1
fi
members=$(tar -tzf release.tar.gz 2>/dev/null) || { echo "❌ release.tar.gz is not a valid tar archive"; exit 1; }
members=$(printf '%s\n' "$members" | sed 's|^\./||')

if printf '%s\n' "$members" | grep -v '^$' | grep -Evq '^app(/|$)'; then
  echo "❌ every member must start with app/ (archive the app directory itself, from the sandbox root)"
  exit 1
fi

# Things that must never be inside, with a reason
check_absent() {  # regex, message
  local hit
  hit=$(printf '%s\n' "$members" | grep -E "$1" | head -1)
  if [ -n "$hit" ]; then echo "❌ release.tar.gz contains $hit: $2"; exit 1; fi
}
check_absent '(^|/)\.git(/|$)' "version control data must stay out"
check_absent '(^|/)\.gitignore$' "VCS files (.gitignore) must stay out"
check_absent '(^|/)node_modules(/|$)' "node_modules must stay out at every depth"
check_absent '(^|/)\.env$' "a .env file with production secrets"
check_absent '\.log$' "log files must stay out"

expected=$(find app \( -name .git -o -name node_modules \) -prune -o \( -type f -o -type l \) -print |
  grep -Ev '(^|/)\.gitignore$|\.log$|(^|/)\.env$' | LC_ALL=C sort)
got=$(printf '%s\n' "$members" | grep -v '/$' | grep -v '^$' | LC_ALL=C sort)
if [ "$got" != "$expected" ]; then
  missing=$(printf '%s\n' "$expected" | grep -vxF -e "$got" | head -1)
  if [ -n "$missing" ]; then
    echo "❌ release.tar.gz is missing $missing (an exclude pattern catches more than it should?)"
  else
    echo "❌ release.tar.gz has $(printf '%s\n' "$got" | grep -c .) files, expected $(printf '%s\n' "$expected" | grep -c .)"
  fi
  exit 1
fi
for m in $expected; do
  if ! tar -xzOf release.tar.gz "$m" 2>/dev/null | cmp -s - "$m"; then
    echo "❌ $m inside release.tar.gz differs from app/; build the archive from the current files"
    exit 1
  fi
done
echo "✅ release.tar.gz ships exactly the $(printf '%s\n' "$expected" | grep -c .) release files, no VCS data, modules, logs or secrets"
exit 0
