#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# Build the backup from a scratch folder, then remove the folder
mkdir -p .build/site/css .build/site/js .build/site/db
printf '<!doctype html>\n<title>Shop</title>\n<h1>Welcome</h1>\n' > .build/site/index.html
printf 'body { font-family: sans-serif; }\n' > .build/site/css/main.css
printf 'console.log("shop v3");\n' > .build/site/js/app.js
printf 'CREATE TABLE orders (id INT, total NUMERIC);\n' > .build/site/db/schema.sql
printf 'RewriteEngine On\n' > .build/site/.htaccess
tar -czf backup.tar.gz -C .build site
rm -rf .build

mkdir -p logs
printf '2024-03-14 10:00:01 INFO  app started\n2024-03-14 10:05:12 INFO  200 GET /\n' > logs/app.log
printf '2024-03-14 10:07:44 ERROR payment timeout\n' > logs/error.log
printf '2024-03-14 09:59:58 INFO  kernel ok\n' > logs/system.log
printf '2024-03-14 10:02:10 WARN  failed login for admin\n' > logs/auth.log
printf '2024-03-13 23:59:59 INFO  rotated\n' > logs/app.log.1
printf 'Logs are rotated nightly at midnight.\n' > logs/README.txt
