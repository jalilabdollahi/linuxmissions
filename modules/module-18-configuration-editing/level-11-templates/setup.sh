#!/bin/bash
# One Config per Environment: envs.csv (header + 4 rows) and a template with four
# {{PLACEHOLDERS}}. prod's DB URL has "/" and "&" and dr's password has "|", "&"
# and "\", which break a naive sed "s/{{X}}/$value/" (and sed with | as delimiter).
# The expected files are rendered with python so the validator is independent of the
# shell techniques the player may use.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state/expected

cat > envs.csv <<'CSV'
env,db_url,db_password,replicas
dev,postgres://dev-db:5432/app,devpass,1
staging,postgres://stg-db:5432/app,stg-pass-77,2
prod,postgres://app@prod-db.internal:5432/app?sslmode=require&pool=40,Pr0d#Secret,6
dr,postgres://app@dr-db.internal:5432/app?sslmode=require,a|b&c\d,3
CSV

cat > app.conf.tmpl <<'CONF'
# app.conf - generated for {{ENV}}, do not edit by hand
[app]
environment = {{ENV}}
replicas = {{REPLICAS}}

[database]
url = {{DB_URL}}
password = {{DB_PASSWORD}}
pool_name = app-{{ENV}}
CONF

python3 -I - <<'PY'
import csv
tmpl = open("app.conf.tmpl").read()
for row in csv.DictReader(open("envs.csv")):
    out = (tmpl.replace("{{ENV}}", row["env"]).replace("{{DB_URL}}", row["db_url"])
               .replace("{{DB_PASSWORD}}", row["db_password"]).replace("{{REPLICAS}}", row["replicas"]))
    open(".lm-state/expected/%s.conf" % row["env"], "w").write(out)
PY
cp envs.csv .lm-state/envs.csv
cp app.conf.tmpl .lm-state/app.conf.tmpl
