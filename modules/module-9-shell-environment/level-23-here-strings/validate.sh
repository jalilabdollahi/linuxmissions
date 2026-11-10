#!/bin/bash
# Runs parse-dsn.sh on DSNs the player has not seen (passwords with @, : and $,
# missing ports, random parts) in an empty directory, then sources the db.env
# it wrote in a clean bash and compares the five values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f parse-dsn.sh ]; then
  echo "❌ parse-dsn.sh is missing (type reset)"
  exit 1
fi
if grep -Eq 'mktemp|/tmp/|/dev/shm' parse-dsn.sh; then
  echo "❌ parse-dsn.sh uses a temporary file; split the DSN in variables only"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

r1=$(printf '%04x' $RANDOM); r2=$(( RANDOM % 900 + 100 )); r3=$(printf '%03x' $(( RANDOM % 4096 )))
# DSN  TAB  user  TAB  password  TAB  host  TAB  port  TAB  dbname
CASES="postgres://app:p@ss@db-2:5432/orders	app	p@ss	db-2	5432	orders
postgres://report:s3:cr3t@analytics.internal/warehouse	report	s3:cr3t	analytics.internal	5432	warehouse
mysql://root:pa\$\$w0rd!@10.0.0.5:3306/shop	root	pa\$\$w0rd!	10.0.0.5	3306	shop
postgres://svc_$r1:Zx@@$r2@pg-$r3.prod:6$r2/app_$r1	svc_$r1	Zx@@$r2	pg-$r3.prod	6$r2	app_$r1
postgresql://etl:a:b@c:d@warehouse-$r2/etl_raw	etl	a:b@c:d	warehouse-$r2	5432	etl_raw
postgres://web:h\$HOME x#1@cache-db:5433/sessions	web	h\$HOME x#1	cache-db	5433	sessions"

n=0
while IFS=$'\t' read -r dsn user pass host port db; do
  n=$(( n + 1 ))
  d="$WORK/case$n"; mkdir -p "$d"
  (cd "$d" && $LIMIT env -i PATH=/usr/bin:/bin HOME="$d" bash "$SANDBOX/parse-dsn.sh" "$dsn" </dev/null >/dev/null 2>"$d.err")
  if [ ! -f "$d/db.env" ]; then
    echo "❌ for $dsn, parse-dsn.sh wrote no db.env in the current directory"
    exit 1
  fi
  other="$(ls -A "$d" | grep -vx 'db.env' | head -1)"
  if [ -n "$other" ]; then
    echo "❌ parse-dsn.sh left a file '$other' behind; no temporary files"
    exit 1
  fi
  (cd "$d" && $LIMIT env -i PATH=/usr/bin:/bin HOME=/nonexistent bash --noprofile --norc -c '
     source ./db.env || exit 3
     printf "%s\037%s\037%s\037%s\037%s\n" "$DB_USER" "$DB_PASS" "$DB_HOST" "$DB_PORT" "$DB_NAME"' \
     </dev/null >"$d.got" 2>"$d.srcerr")
  if [ -s "$d.srcerr" ]; then
    echo "❌ for $dsn, \`source db.env\` fails: $(head -1 "$d.srcerr" | sed 's/^.*db.env: //')"
    exit 1
  fi
  IFS=$'\037' read -r gu gp gh gpo gd < "$d.got"
  for pair in "DB_USER|$gu|$user" "DB_PASS|$gp|$pass" "DB_HOST|$gh|$host" "DB_PORT|$gpo|$port" "DB_NAME|$gd|$db"; do
    IFS='|' read -r k got want <<< "$pair"
    if [ "$got" != "$want" ]; then
      if [ -z "$gu$gp$gh$gpo$gd" ]; then
        echo "❌ for $dsn, every value in db.env is empty: the variables set by read got lost somewhere"
      else
        echo "❌ for $dsn, $k is '$got' after source db.env, expected '$want'"
      fi
      exit 1
    fi
  done
done <<< "$CASES"

echo "✅ parse-dsn.sh splits all $n DSNs correctly, and db.env loads them unchanged"
exit 0
