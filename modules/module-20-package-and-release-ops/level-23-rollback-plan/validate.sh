#!/bin/bash
# current must be a symlink to the last good release (never a dir), nothing stray inside releases/,
# 1.6.0 intact, /health 200 with that version (so the app reloaded), and one well-formed ROLLBACK line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
GOOD=$(cat .lm/good)
PORT=$(cat app.port)
if [ -d current ] && [ ! -L current ]; then
  echo "❌ current is a real directory now, it must be a symlink to a release"
  exit 1
fi
if [ ! -L current ]; then
  echo "❌ current does not exist or is not a symlink"
  exit 1
fi
stray=$(find releases -type l | head -1)
if [ -n "$stray" ]; then
  echo "❌ there is a symlink inside releases/ ($stray): ln -sf on a symlink that points to a directory creates the link inside that directory (use -n)"
  exit 1
fi
if [ ! -d releases/1.6.0 ] || ! (md5sum -c --quiet .lm/r160.md5 >/dev/null 2>&1); then
  echo "❌ releases/1.6.0 was changed or removed: keep it as it is for forensics"
  exit 1
fi
target=$(basename "$(readlink -f current)")
if [ "$target" = "1.6.0" ]; then
  echo "❌ current still points at 1.6.0"
  exit 1
fi
if [ "$(readlink -f current)" != "$SANDBOX/releases/$target" ]; then
  echo "❌ current does not point to a directory under releases/"
  exit 1
fi
if [ "$target" != "$GOOD" ]; then
  if grep -qx "$target" .lm/rolledback; then
    echo "❌ current points at $target, which was rolled back or failed earlier: check deploy.log for the last release that was ok and stayed"
  else
    echo "❌ current points at $target, which is not the most recent good release (releases/ has newer ones that were deployed ok and stayed)"
  fi
  exit 1
fi
code=$(curl -s -m 3 -o .lm/health.json -w '%{http_code}' "http://127.0.0.1:$PORT/health")
if [ "$code" != "200" ]; then
  echo "❌ /health answers $code (current is right, but the running app still has the old release loaded: make it re-read current)"
  exit 1
fi
if [ "$(jq -r .version .lm/health.json)" != "$GOOD" ]; then
  echo "❌ /health is 200 but reports version $(jq -r .version .lm/health.json), not $GOOD"
  exit 1
fi
n=$(wc -l < .lm/log.orig)
if ! head -n "$n" deploy.log | cmp -s - .lm/log.orig; then
  echo "❌ existing lines of deploy.log were changed: only append"
  exit 1
fi
if [ "$(wc -l < deploy.log)" -ne $((n + 1)) ]; then
  echo "❌ deploy.log should have exactly one new line (ROLLBACK ...), it has $(( $(wc -l < deploy.log) - n ))"
  exit 1
fi
last=$(tail -1 deploy.log)
if ! echo "$last" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ROLLBACK 1\.6\.0 -> $GOOD [^ ]"; then
  echo "❌ the new deploy.log line is not '<UTC timestamp> ROLLBACK 1.6.0 -> $GOOD <reason>' (timestamp like 2026-11-10T09:15:00Z)"
  exit 1
fi
echo "✅ rolled back to $GOOD: current is a symlink, /health is 200, 1.6.0 is kept, deploy.log updated"
