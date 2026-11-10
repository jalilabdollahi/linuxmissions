#!/bin/bash
# Someone ran chmod -R 777 on the app tree. perms.acl is last month's
# `getfacl -R app` dump (named-user ACL entries, a path with a space written
# as \040); a few paths were created after the dump and are not in it.
# Linux only: needs a filesystem with ACL support and setfacl/getfacl.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
python3 - <<'PY'
import os, random
R = random.Random()
def mk(path, mode, text="x\n", d=False):
    if d:
        os.makedirs(path, exist_ok=True)
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(text * R.randint(1, 5))
    os.chmod(path, mode)
D = [("app", 0o2750), ("app/bin", 0o2750), ("app/config", 0o2750), ("app/config/secrets", 0o2750),
     ("app/data", 0o2750), ("app/docs", 0o2750), ("app/uploads", 0o1770)]
for p, m in D: mk(p, m, d=True)
F = [("app/bin/start.sh", 0o750), ("app/bin/migrate.sh", 0o750), ("app/config/app.conf", 0o640),
     ("app/config/legacy.conf", 0o644), ("app/config/secrets/db.pass", 0o600),
     ("app/config/secrets/api.key", 0o600), ("app/data/orders.db", 0o640),
     ("app/docs/user guide.txt", 0o640), ("app/docs/runbook.md", 0o640)]
for p, m in F: mk(p, m)
open("app/data/orders.db", "w").write("db\n" * 400)
PY
setfacl -m u:daemon:r-- app/config/app.conf
setfacl -m u:www-data:r-x app/bin/start.sh
setfacl -m u:daemon:r-- "app/docs/user guide.txt"
setfacl -m u:www-data:rwx,m::rwx app/uploads
getfacl -R app > perms.acl 2>/dev/null
find app -exec touch -h -d '2026-10-01 10:00' {} +
touch -d '2026-10-10 03:00' perms.acl
# created since the dump (not in it)
mkdir -p app/data/2026-11 app/config/secrets
echo 'token=%s' > app/config/secrets/ingest-token.txt
printf '#!/bin/sh\necho report\n' > app/bin/report.sh
seq 1 50 > app/data/2026-11/export.csv
echo "new notes" > app/docs/changelog-nov.md
echo "upload" > app/uploads/receipt-8841.pdf
for p in app/data/2026-11 app/config/secrets/ingest-token.txt app/bin/report.sh app/data/2026-11/export.csv app/docs/changelog-nov.md app/uploads/receipt-8841.pdf; do
  touch -d '2026-11-03 09:00' "$p"
done
for p in app/data app/config/secrets app/bin app/docs app/uploads; do touch -d '2026-10-01 10:00' "$p"; done
chmod -R 777 app
chmod 000 app/config/secrets/db.pass
cat > POLICY.md <<'MD'
# Permission policy for /srv/app

Every path in last month's dump (`perms.acl`, a `getfacl -R app` capture)
keeps exactly the mode and ACL it had there. Everything created since then
follows this policy:

- directories: 2750 (setgid, group may read)
- regular files: 640
- files in a `bin/` directory: 750
- files in a `secrets/` directory: 600
- nothing is world-writable. `app/uploads/` itself is the only sticky
  directory (1770); it is already in the dump.

New paths get no named-user ACL entries.
MD
cat > TICKET.md <<'MD'
Someone ran `chmod -R 777 app` to "fix" a permission error. After a quick fix
of the secrets the app still cannot read its database password. Restore the tree.
MD
