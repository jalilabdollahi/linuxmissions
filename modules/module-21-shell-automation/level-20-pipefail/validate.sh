#!/bin/bash
# Checks that backup_db.sh turns on pipefail, then runs it in scratch copies
# with a mock pg_dump: a good dump with warnings, a good dump with none, a
# dump that dies halfway, and a good dump where gzip fails (a mock gzip that
# reports a full disk). Good runs: exit 0, a .gz that holds the whole dump and
# the right warning count. Failed runs: exit non-zero, no db.sql.gz, and a
# "backup FAILED:" line on stderr that names the stage that failed.
SANDBOX="$1"
SCRIPT="$SANDBOX/backup_db.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ backup_db.sh is missing (type reset to get it back)"
  exit 1
fi
if ! sed 's/#.*//' "$SCRIPT" | grep -Eq '^[[:space:]]*set[[:space:]].*-[a-zA-Z]*o[[:space:]]+pipefail'; then
  echo "❌ backup_db.sh does not turn on 'set -o pipefail' yet"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

mkdir -p "$WORK/fullbin"
cat > "$WORK/fullbin/gzip" <<'MOCK'
#!/bin/bash
cat > /dev/null
echo "gzip: stdout: No space left on device" >&2
exit 1
MOCK
chmod +x "$WORK/fullbin/gzip"
SEED=$RANDOM

# attempt NAME [VAR=value...]: run backup_db.sh in $R
attempt() {
  R="$WORK/$1"; shift
  mkdir -p "$R/bin"
  cp "$SCRIPT" "$R/backup_db.sh"
  cat > "$R/bin/pg_dump" <<MOCK
#!/bin/bash
w="\${PGDUMP_WARNINGS:-2}"
i=0
while [ "\$i" -lt "\$w" ]; do echo "pg_dump: warning: check \$i" >&2; i=\$((i + 1)); done
echo "-- dump of \$1 ($SEED)"
i=1
while [ "\$i" -le 300 ]; do
  if [ "\${PGDUMP_FAIL:-0}" = 1 ] && [ "\$i" -gt 120 ]; then
    echo "pg_dump: error: connection to server was lost" >&2
    exit 1
  fi
  echo "INSERT INTO t VALUES (\$i, $SEED);"
  i=\$((i + 1))
done
echo "-- dump complete"
MOCK
  chmod +x "$R/bin/pg_dump"
  (cd "$R" && $LIMIT env "$@" bash ./backup_db.sh </dev/null >"$R/.out" 2>"$R/.err")
  CODE=$?
}

# good NAME WARNINGS
good() {
  if [ "$CODE" != 0 ]; then
    msg="$(grep -v '^pg_dump: warning' "$R/.err" | head -1)"
    echo "❌ $1: backup_db.sh exited with status $CODE: ${msg:-no message, a command failed and set -e stopped the script}"
    exit 1
  fi
  want="$(cd "$R" && bin/pg_dump shop 2>/dev/null)"
  if [ "$(gzip -dc "$R/backups/db.sql.gz" 2>/dev/null)" != "$want" ]; then
    echo "❌ $1: backups/db.sql.gz does not contain the complete dump"
    exit 1
  fi
  if ! grep -q "backup ok" "$R/.out" || ! grep -q "($2 warnings)" "$R/.out"; then
    echo "❌ $1: stdout should still say 'backup ok: ... ($2 warnings)'; got: $(head -1 "$R/.out")"
    exit 1
  fi
}

# failed NAME STAGE OTHER
failed() {
  if [ "$CODE" = 0 ]; then
    echo "❌ $1: backup_db.sh still exits 0"
    exit 1
  fi
  if [ -e "$R/backups/db.sql.gz" ]; then
    echo "❌ $1: backup_db.sh fails, but leaves a partial backups/db.sql.gz behind; remove it"
    exit 1
  fi
  line="$(grep '^backup FAILED:' "$R/.err" | head -1)"
  if [ -z "$line" ]; then
    echo "❌ $1: no 'backup FAILED: ...' line on stderr"
    exit 1
  fi
  case "$line" in
    *"$3"*) echo "❌ $1: the FAILED line should name only the stage that failed ($2), but it also mentions $3: '$line'"; exit 1 ;;
    *"$2"*) ;;
    *) echo "❌ $1: the FAILED line should name the stage that failed ($2): '$line'"; exit 1 ;;
  esac
  if grep -q "backup ok" "$R/.out"; then
    echo "❌ $1: backup_db.sh still prints 'backup ok'"
    exit 1
  fi
}

attempt warn PGDUMP_WARNINGS=3
good "a good dump with 3 warnings" 3

attempt nowarn PGDUMP_WARNINGS=0
good "a good dump with no warnings" 0

attempt dumpfail PGDUMP_FAIL=1
failed "when pg_dump loses the connection" pg_dump gzip

attempt diskfull PGDUMP_WARNINGS=1 PATH="$WORK/fullbin:$PATH"
failed "when gzip cannot write (disk full)" gzip pg_dump

echo "✅ backup_db.sh fails on any broken stage, names it, removes the partial file, and still passes a clean night"
exit 0
