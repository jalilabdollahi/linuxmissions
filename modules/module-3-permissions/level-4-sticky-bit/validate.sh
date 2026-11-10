#!/bin/bash
SANDBOX="$1"
DIR="$SANDBOX/shared"

if [ ! -d "$DIR" ]; then
  echo "❌ shared/ is gone (type reset to get it back)"
  exit 1
fi
for f in alice_budget.xlsx bob_photos.zip carol_notes.txt; do
  if [ ! -f "$DIR/$f" ]; then
    echo "❌ shared/$f was deleted; the uploads must stay (type reset to start over)"
    exit 1
  fi
done

# GNU stat prints 1777; on macOS %Lp leaves out the special bits, %Mp adds them
MODE=$(stat -c '%a' "$DIR" 2>/dev/null || stat -f '%Mp%Lp' "$DIR")
MODE=${MODE#0}
if ! (( 8#$MODE & 8#1000 )); then
  echo "❌ shared/ still lets anyone delete anyone's files (mode $MODE, no sticky bit)"
  exit 1
fi
if [ $(( 8#$MODE & 8#777 )) -ne $(( 8#777 )) ]; then
  echo "❌ shared/ has the sticky bit, but is no longer rwx for everyone (mode $MODE): others must still be able to upload"
  exit 1
fi
echo "✅ shared/ is $MODE: everyone can upload, only owners can delete their files"
exit 0
