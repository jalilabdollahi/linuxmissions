#!/bin/bash
export PATH="$PWD/bin:$PATH"   # in the game the sandbox bin/ is first on PATH already
# One small sed per file, on the line the checker named (found by running --check-config in a loop).
sed -i -e 's/^workers 4/workers = 4/' -e 's|^\(port = [0-9]*\)/tcp|\1|' etc/app/app.ini
sed -i -e 's/^APP_VERSION = /APP_VERSION=/' -e 's/^APP_ENV=prod$/APP_ENV=production/' etc/app/app.env
sed -i -e '/"checkout": false,/d' -e 's/"beta_ui": false,$/"beta_ui": false/' etc/app/features.json
sed -i -e 's/^\t/    /' -e 's/port: "6379"/port: 6379/' etc/app/services.yml
sed -i 's/^127\.0\.01 /127.0.0.1 /' etc/app/hosts
app --check-config && app start
curl -s "http://127.0.0.1:$(sed -n 's/^port = //p' etc/app/app.ini)/"
