#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX/etc/myapp" 2>/dev/null || { echo "❌ etc/myapp is missing; type 'reset'"; exit 1; }

# The config files themselves must be untouched
for v in 1 2; do
  f="v$v/config.conf"
  if [ -L "$f" ] || [ ! -f "$f" ] || [ "$(head -n 1 "$f")" != "version=$v" ]; then
    echo "❌ $f was moved, replaced or edited; type 'reset' and only change active.conf"
    exit 1
  fi
done

if [ ! -L active.conf ]; then
  if [ -e active.conf ]; then
    echo "❌ active.conf is a regular file now, not a symlink (was it copied?)"
  else
    echo "❌ etc/myapp/active.conf does not exist"
  fi
  exit 1
fi

TARGET=$(readlink active.conf)
if [ ! -e active.conf ]; then
  echo "❌ active.conf -> $TARGET is broken: a relative target is resolved from the link's own folder (etc/myapp)"
  exit 1
fi
if ! [ active.conf -ef v2/config.conf ]; then
  echo "❌ active.conf -> $TARGET does not lead to v2/config.conf"
  exit 1
fi
case "$TARGET" in
  /*) echo "❌ active.conf points to an absolute path ($TARGET); make the target relative to etc/myapp"
      exit 1 ;;
esac
echo "✅ active.conf -> $TARGET (relative, version 2)"
exit 0
