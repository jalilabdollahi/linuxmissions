#!/bin/bash
SANDBOX="$1"
echo "<html>hello</html>" > "$SANDBOX/index.html"
echo "#!/usr/bin/env python3" > "$SANDBOX/app.py"
echo "DB_PASSWORD=secret" > "$SANDBOX/secrets.conf"
# All start with wrong permissions
chmod 777 "$SANDBOX/index.html" "$SANDBOX/app.py" "$SANDBOX/secrets.conf"
