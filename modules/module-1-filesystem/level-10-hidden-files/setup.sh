#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

TOKEN="tk_$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"

mkdir -p .config/app .cache/app .local/share/app config logs

# The real one: hidden file inside a hidden folder
cat > .config/app/.credentials <<CRED
# written by 'app login' - do not edit
AUTH_USER=deploy
AUTH_TOKEN=$TOKEN
AUTH_EXPIRES=2025-12-31
CRED

# Look-alikes and noise
printf '# copy to .env and fill in\nAUTH_TOKEN=<paste-your-token-here>\nAPI_URL=https://api.example.com\n' > .env.example
printf 'Credentials no longer live here. Since v2 the app keeps them in its config dir.\n' > config/credentials.txt
printf 'theme=dark\nlanguage=en\n' > .config/app/settings.ini
printf '{"last_sync": "2024-03-14T10:00:00Z"}\n' > .cache/app/state.json
printf 'login ok\nsync ok\n' > .local/share/app/.history
printf 'My App\n======\nRun ./app to start.\n' > readme.txt
printf 'port=8080\n' > app.conf
printf '2024-03-14 10:00:01 INFO started\n' > logs/app.log
