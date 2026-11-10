#!/bin/bash
# Nightly backup that "succeeds" but archives nothing useful.
# Faults: unquoted $SRC (the share path has a space), a `*` glob that is
# expanded in the wrong directory and skips dotfiles, and tar|gzip without
# pipefail, so tar's failure never reaches the exit status.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p "office share/data" backups logs .lm-state
python3 - <<'PY'
import os, random, time
R = random.Random()
base = "office share/data"
def w(path, text):
    path = os.path.join(base, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
q = R.choice(["Q2", "Q3", "Q4"])
w("reports/%s summary.txt" % q, "".join("line %d revenue %d\n" % (i, R.randint(1000, 99999)) for i in range(40)))
w("reports/archive/%s-detail.csv" % q.lower(), "id,amount\n" + "".join("%d,%d\n" % (i, R.randint(1, 5000)) for i in range(300)))
w(".env.production", "DB_HOST=db-%d.internal\nDB_PASS=%s\n" % (R.randint(1, 9), "".join(R.choice("abcdef0123456789") for _ in range(24))))
w("config/app.ini", "[app]\nworkers=%d\nlisten=0.0.0.0:%d\n" % (R.randint(2, 16), R.randint(8000, 8999)))
w("config/.local-overrides", "debug=%s\n" % R.choice(["0", "1"]))
w("db/dump.sql", "".join("INSERT INTO t VALUES (%d,'%s');\n" % (i, R.randint(10**8, 10**9)) for i in range(800)))
w("notes/.drafts/todo.md", "- check restore test\n- rotate keys %d\n" % R.randint(1, 99))
PY
# a week of "successful" runs and nearly empty archives
mkdir -p .lm-state/junk && echo x > .lm-state/junk/stray.txt
for d in 03 04 05 06 07 08 09; do
  tar -czf "backups/data-2026-11-$d-020001.tar.gz" -C .lm-state/junk .
  echo "2026-11-$d 02:00:02 backup ok: data-2026-11-$d-020001.tar.gz" >> logs/backup.log
done
cat > backup.sh <<'SH'
#!/bin/bash
# Nightly backup of the office share. Run by cron at 02:00.
BASE=$(cd "$(dirname "$0")" && pwd)
SRC="$BASE/office share/data"
DEST=$BASE/backups
LOG=$BASE/logs/backup.log
OUT=$DEST/data-$(date +%F-%H%M%S).tar.gz

tar -cf - -C $SRC * 2>/dev/null | gzip > "$OUT"
echo "$(date '+%F %T') backup ok: $(basename "$OUT")" >> "$LOG"
SH
chmod 755 backup.sh
cat > RESTORE-TEST.md <<'MD'
# Restore test, Tuesday

Extracted last night's archive into a scratch directory and compared it with
the share: almost nothing is in there (2 KB). Compared to the 11 MB we had
last quarter. The log says "backup ok" every night.
MD
touch .lm-state/stamp
sleep 1
