#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/release"
echo "listen=8080" > "$SANDBOX/release/app.conf"
echo "#!/bin/bash" > "$SANDBOX/release/start.sh"
# macOS gives new files in /tmp the group 'wheel'; use your own group like Linux does
chgrp -R "$(id -g)" "$SANDBOX" 2>/dev/null

# The paths the failed deploy touched: system files (root's) mixed with your own.
: > "$SANDBOX/paths.txt"
for p in /etc/passwd /etc/shadow /usr/bin/passwd "$SANDBOX/release/app.conf" \
         /var/mail /etc/hosts "$HOME" "$SANDBOX/release"; do
  if [ -e "$p" ] && [ ! -L "$p" ]; then
    echo "$p" >> "$SANDBOX/paths.txt"
  fi
done
