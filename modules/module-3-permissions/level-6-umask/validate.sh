#!/bin/bash
SANDBOX="$1"

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

if [ ! -f "$SANDBOX/start_app.sh" ]; then
  echo "❌ start_app.sh is gone (type reset to get it back)"
  exit 1
fi

# 1. Does the script itself now create files with the right modes?
#    Run a copy in a scratch folder inside the sandbox.
TRY="$SANDBOX/.umask-check"
rm -rf "$TRY"; mkdir -p "$TRY"
cp "$SANDBOX/start_app.sh" "$TRY/"
( cd "$TRY" && bash ./start_app.sh ) >/dev/null 2>&1
new_file=$(mode_of "$TRY/data/reports/daily/sales.csv" 2>/dev/null)
new_dir=$(mode_of "$TRY/data/reports/daily" 2>/dev/null)
rm -rf "$TRY"
if [ "$new_file" != "640" ] || [ "$new_dir" != "750" ]; then
  echo "❌ start_app.sh still creates files as ${new_file:-?} and directories as ${new_dir:-?} (want 640 and 750)"
  exit 1
fi

# 2. Are the files that already existed fixed too?
if [ ! -f "$SANDBOX/data/app.log" ] || [ ! -f "$SANDBOX/data/reports/daily/sales.csv" ]; then
  echo "❌ data/ is incomplete: run start_app.sh so the reports exist"
  exit 1
fi
bad=0
while IFS= read -r p; do
  if [ -d "$p" ]; then want=750; else want=640; fi
  [ "$(mode_of "$p")" != "$want" ] && bad=$((bad + 1))
done < <(find "$SANDBOX/data")
if [ "$bad" -gt 0 ]; then
  echo "❌ start_app.sh is fixed, but $bad existing item(s) under data/ still have the old modes"
  exit 1
fi

echo "✅ start_app.sh now creates 640 files / 750 dirs, and data/ is locked down"
exit 0
