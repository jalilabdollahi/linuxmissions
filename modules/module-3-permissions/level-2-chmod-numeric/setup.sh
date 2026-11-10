#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/index.html" <<'HTML'
<!doctype html>
<html><body><h1>Order tracker</h1></body></html>
HTML
cat > "$SANDBOX/app.py" <<'PY'
#!/usr/bin/env python3
print("order tracker running")
PY
cat > "$SANDBOX/secrets.conf" <<'CONF'
DB_USER=tracker
DB_PASSWORD=Sup3r-S3cret-2024
CONF
# The "quick fix" that caused the problem
chmod 777 "$SANDBOX/index.html" "$SANDBOX/app.py" "$SANDBOX/secrets.conf"
