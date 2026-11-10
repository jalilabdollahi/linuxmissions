#!/bin/bash
SANDBOX="$1"
W="$SANDBOX/webroot"

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

for f in index.html pages/about.html pages/contact.html "pages/blog/launch day.html" \
         static/css/style.css static/js/app.js "static/img/team photo.jpg" .htaccess; do
  if [ ! -f "$W/$f" ]; then
    echo "❌ webroot/$f is missing; fix permissions, don't delete files (type reset to start over)"
    exit 1
  fi
done

bad_dirs=0
while IFS= read -r -d '' d; do
  [ "$(mode_of "$d")" != "755" ] && bad_dirs=$((bad_dirs + 1))
done < <(find "$W" -type d -print0)
bad_files=0
while IFS= read -r -d '' f; do
  [ "$(mode_of "$f")" != "644" ] && bad_files=$((bad_files + 1))
done < <(find "$W" -type f -print0)

if [ "$bad_dirs" -gt 0 ] || [ "$bad_files" -gt 0 ]; then
  echo "❌ Still wrong: $bad_dirs director(y/ies) not 755, $bad_files file(s) not 644"
  exit 1
fi
echo "✅ webroot/: every directory is 755 and every file is 644"
exit 0
