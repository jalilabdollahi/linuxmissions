#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p config deploy scripts services/auth services/billing services/search docs

# Filler that does not leak anything
for svc in auth billing search; do
  printf 'service=%s\nport=80%02d\nlog_level=info\n' "$svc" "${#svc}" > "services/$svc/service.conf"
  printf 'replicas=2\ncpu=500m\n' > "services/$svc/resources.conf"
done
printf 'host=db.internal\nport=5432\nuser=app\n' > config/database.conf
printf 'debug=false\ntimezone=UTC\n' > config/app.conf
printf 'APP_ENV=production\nWORKERS=4\n' > deploy/env.txt
printf '#!/bin/bash\nread -s -p "password: " PW\n./start --auth "$PW"\n' > scripts/start.sh
printf 'password_min_length=12\npassword_max_age_days=90\n' > services/auth/policy.conf
printf '# Secrets\nNever put a password = value in a file; use the vault.\n' > docs/SECURITY.md
printf 'user: app\npassword: ${DB_PASSWORD}\n' > deploy/compose.yml

# The leaks (5 files)
printf 'password=Winter2024!\n' >> config/database.conf
printf '[billing]\ngateway=stripe\ndb_password=b1ll1ng-s3cret\n' > services/billing/settings.ini
printf 'smtp_host=mail.internal\nsmtp_password=hunter2\n' > .env
printf '; old settings, kept for reference\nuser=admin\npassword=admin123\n' > "deploy/old settings.ini"
printf '#!/bin/bash\n# TODO remove before commit\nmysql -u root --password=toor < dump.sql\n' > scripts/restore-db.sh
