#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX"/{config,deploy,scripts}
echo "host=db.internal" > "$SANDBOX/config/database.conf"
echo "port=5432" >> "$SANDBOX/config/database.conf"
echo "password=supersecret123" >> "$SANDBOX/config/database.conf"
echo "APP_ENV=production" > "$SANDBOX/deploy/env.txt"
echo "WORKERS=4" >> "$SANDBOX/deploy/env.txt"
echo "#!/bin/bash" > "$SANDBOX/scripts/start.sh"
echo "echo 'starting app'" >> "$SANDBOX/scripts/start.sh"
echo "debug=false" > "$SANDBOX/config/app.conf"
