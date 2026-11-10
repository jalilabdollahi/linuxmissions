#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

OLD_APP=$'# app.conf - release 4.1 (live)\nlisten=8080\nworkers=4\ncheckout=legacy'
NEW_APP=$'# app.conf - release 4.2\nlisten=8080\nworkers=8\ncheckout=v2'

# 1) the rollback copy
if [ ! -f production/app.conf.old ]; then
  if [ -f production/app.conf ] && [ "$(cat production/app.conf)" = "$NEW_APP" ]; then
    echo "❌ the live app.conf was replaced before it was backed up; type 'reset' and copy it first"
  else
    echo "❌ production/app.conf.old (the backup of the live config) does not exist yet"
  fi
  exit 1
fi
if [ "$(cat production/app.conf.old)" != "$OLD_APP" ]; then
  echo "❌ production/app.conf.old is not a copy of the 4.1 config; type 'reset' and back it up first"
  exit 1
fi

# 2) the .conf files from staging, with their 4.2 content
expect() {  # file expected-content
  if [ ! -f "production/$1" ]; then
    echo "❌ production/$1 is missing"; exit 1
  fi
  if [ "$(cat "production/$1")" != "$2" ]; then
    echo "❌ production/$1 does not have the release 4.2 content"; exit 1
  fi
}
expect db.conf $'host=db-primary.internal\nport=5432\npool=20'
expect web.conf $'server_name=shop.example.com\nport=443'
expect logging.conf $'level=info\nformat=json'
expect cache.conf $'backend=redis\nttl=300'

# 3) the new app.conf
if [ "$(cat production/app.conf 2>/dev/null)" != "$NEW_APP" ]; then
  echo "❌ production/app.conf is not the release 4.2 config yet"
  exit 1
fi
if [ -e production/app.conf.new ]; then
  echo "❌ production/app.conf.new should have been renamed to app.conf"
  exit 1
fi

# staging/ must be emptied by moving, not copying
rest=$(ls -A staging 2>/dev/null | grep -vx 'notes.txt' | tr '\n' ' ')
if [ -n "$rest" ]; then
  echo "❌ staging/ still contains: $rest(move files, don't copy them)"
  exit 1
fi
if [ ! -f staging/notes.txt ]; then
  echo "❌ staging/notes.txt should have stayed in staging/"
  exit 1
fi
echo "✅ release 4.2 installed, 4.1 config kept as app.conf.old, staging/ cleaned up"
exit 0
