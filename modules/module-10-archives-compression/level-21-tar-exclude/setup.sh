#!/bin/bash
# $1 = sandbox path
# A Node app checkout with everything a release must not carry (.git, two
# node_modules, logs, two .env files) next to look-alikes that must ship
# (.env.example, logs/.keep, .github/, changelog.md, logger.js, logrotate.conf).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

w() { mkdir -p "$(dirname "$1")"; printf '%b' "$2" > "$1"; }

w app/package.json '{\n  "name": "orders-api",\n  "version": "2.4.0",\n  "main": "src/index.js"\n}\n'
w app/README.md '# orders-api\n\nRun `npm ci && npm start`. Copy .env.example to .env first.\n'
w app/src/index.js "const log = require('./logger');\nrequire('./routes/orders');\nlog.info('listening on ' + (process.env.PORT || 8080));\n"
w app/src/logger.js "module.exports = { info: (m) => console.log(new Date().toISOString(), m) };\n"
w app/src/routes/orders.js "module.exports = function orders(req, res) { res.json([]); };\n"
w app/docs/changelog.md '## 2.4.0\n- refunds endpoint\n- faster order search\n'
w app/config/logrotate.conf '/var/log/orders-api/*.log {\n  daily\n  rotate 14\n  compress\n}\n'
w app/.github/workflows/release.yml 'on: { push: { tags: ["v*"] } }\njobs: { build: { runs-on: ubuntu-latest } }\n'
w app/.env.example 'PORT=8080\nDB_URL=postgres://user:password@localhost/orders\nSTRIPE_KEY=\n'
w app/.env "PORT=8080\nDB_URL=postgres://orders:Xk$RANDOM$RANDOM@db-01/orders\nSTRIPE_KEY=sk_live_$RANDOM$RANDOM$RANDOM\n"
w app/.gitignore 'node_modules/\n*.log\n.env\n'
w app/logs/.keep ''
w app/logs/app.log "2026-11-10T08:00:01Z info listening on 8080\n2026-11-10T08:03:12Z error db timeout\n"
w app/logs/2026-11-09.log '2026-11-09T23:59:59Z info rotated\n'
w app/npm-debug.log '0 info it worked if it ends with ok\n1 verbose cli [ "node", "npm", "start" ]\n'
w app/services/worker/main.js "setInterval(() => console.log('tick'), 60000);\n"
w app/services/worker/.env "QUEUE_URL=redis://:pw$RANDOM@redis-01:6379/0\n"
w app/services/worker/.env.example 'QUEUE_URL=redis://localhost:6379/0\n'
w app/services/worker/worker.log '2026-11-10T07:00:00Z tick\n'
for m in express lodash pg; do
  w "app/node_modules/$m/package.json" "{ \"name\": \"$m\" }\n"
  w "app/node_modules/$m/index.js" "module.exports = {};\n"
done
w app/node_modules/.bin/README 'npm binaries\n'
w app/services/worker/node_modules/bull/index.js "module.exports = {};\n"
w app/.git/HEAD 'ref: refs/heads/main\n'
w app/.git/config '[core]\n\trepositoryformatversion = 0\n'
w app/.git/refs/heads/main "$(printf '%040x' $RANDOM)\n"
w app/.git/objects/4b/825dc642cb6eb9a060e54bf8d69288fbee4904 'x\001\000\000'

cat > RELEASE-CHECKLIST.txt <<'EOF'
orders-api release tarball (release.tar.gz, unpacks into app/):
  - no version control data: the .git directory and .gitignore stay out
  - no node_modules (the deploy runs npm ci), at any depth
  - no *.log files, wherever they are
  - no .env files: they hold production secrets
  - but DO ship the .env.example templates, logs/.keep (so the deploy has a
    logs/ dir) and .github/ (the CI config is part of the release)
EOF
