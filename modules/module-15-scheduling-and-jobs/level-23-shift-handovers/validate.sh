#!/bin/bash
# inventory.tsv must equal the golden list of 25 scheduled items (any order),
# and the sources must be untouched.
SANDBOX="$(cd "$1" && pwd)"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import hashlib
import os
import sys

sandbox = sys.argv[1]
CR = "var/spool/cron/crontabs/"
GOLD = [
    # user crontabs
    (CR + "alice", "alice", "30 7 * * 1-5", "/home/alice/bin/standup-reminder"),
    (CR + "alice", "alice", "0 */4 * * *", "/home/alice/bin/sync-notes --quiet"),
    (CR + "alice", "alice", "@reboot", "/home/alice/bin/start-tmux-session"),
    (CR + "deploy", "deploy", "*/5 * * * *", "/srv/app/bin/queue-depth --push  >/dev/null 2>&1"),
    (CR + "deploy", "deploy", "10 2 * * *", "/srv/app/bin/db-backup --target s3://bk/db   # nightly, see wiki"),
    (CR + "deploy", "deploy", "0 4 1 * *", "/srv/app/bin/rotate-certs; /srv/app/bin/reload-nginx"),
    (CR + "deploy", "deploy", "5 0 * * *", '[ "$(date +\\%u)" = 1 ] && /srv/app/bin/weekly-digest'),
    (CR + "www-data", "www-data", "*/15 * * * *", "php /var/www/html/cron.php > /dev/null"),
    # /etc/crontab
    ("etc/crontab", "root", "17 * * * *", "cd / && run-parts --report /etc/cron.hourly"),
    ("etc/crontab", "root", "25 6 * * *", "test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }"),
    ("etc/crontab", "root", "47 6 * * 7", "test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }"),
    ("etc/crontab", "root", "52 6 1 * *", "test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }"),
    ("etc/crontab", "backup", "0 1 * * *", "/usr/local/bin/nightly-snapshot"),
    # /etc/cron.d
    ("etc/cron.d/backup", "backup", "30 1 * * 1-6", "/usr/local/bin/backup.sh incremental"),
    ("etc/cron.d/backup", "backup", "30 1 * * 0", "/usr/local/bin/backup.sh full"),
    ("etc/cron.d/certbot", "root", "0 */12 * * *",
     "test -x /usr/bin/certbot -a \\! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew"),
    ("etc/cron.d/sysstat", "root", "5-55/10 * * * *", "command -v debian-sa1 > /dev/null && debian-sa1 1 1"),
    ("etc/cron.d/sysstat", "root", "59 23 * * *", "command -v debian-sa1 > /dev/null && debian-sa1 60 2"),
    # enabled systemd timers
    ("etc/systemd/system/apt-clean.timer", "root", "daily", "/usr/bin/apt-get clean"),
    ("etc/systemd/system/db-vacuum.timer", "postgres", "Sun *-*-* 03:00:00", "/usr/local/bin/db-vacuum --analyze"),
    ("etc/systemd/system/fstrim.timer", "root", "weekly", "/sbin/fstrim -av"),
    ("etc/systemd/system/report-weekly.timer", "reports", "Mon *-*-* 07:30:00", "/opt/reports/weekly.sh"),
    # at queue
    ("at:41", "alice", "2026-11-11 03:00", "/usr/local/bin/rotate-keys --now"),
    ("at:42", "deploy", "2026-11-11 22:30", "/srv/app/bin/db-backup --target s3://bk/db --full"),
    ("at:43", "root", "2026-11-12 06:00", "systemctl restart nginx"),
]


def fail(msg):
    print(msg)
    sys.exit(1)


# sources untouched
cur = []
for base in ("var", "etc"):
    for dp, dn, fn in os.walk(os.path.join(sandbox, base)):
        for n in fn + [d for d in dn if os.path.islink(os.path.join(dp, d))]:
            p = os.path.join(dp, n)
            rel = os.path.relpath(p, sandbox)
            if os.path.islink(p):
                cur.append(f"L {rel} {os.readlink(p)}")
            else:
                cur.append(f"F {rel} {hashlib.sha256(open(p, 'rb').read()).hexdigest()}")
want = [l.rstrip("\n") for l in open(os.path.join(sandbox, ".lm/sources.txt"))]
if sorted(cur) != sorted(want):
    fail("❌ a file under var/ or etc/ was changed, added or removed: read the sources, don't edit them (type reset to restore)")

path = os.path.join(sandbox, "inventory.tsv")
if not os.path.isfile(path):
    fail("❌ inventory.tsv does not exist yet")
rows = []
for i, line in enumerate(open(path, encoding="utf-8", errors="replace").read().split("\n"), 1):
    if line == "":
        continue
    cols = line.split("\t")
    if len(cols) != 4:
        fail(f"❌ inventory.tsv line {i} has {len(cols)} tab-separated column(s), expected 4 (source, user, schedule, command)")
    rows.append(tuple(cols))
if len(set(rows)) != len(rows):
    dup = [r for r in rows if rows.count(r) > 1][0]
    fail(f"❌ inventory.tsv lists the same item twice (source {dup[0]})")
gold = set(GOLD)
got = set(rows)
extra = sorted(got - gold)
missing = sorted(gold - got)
if extra:
    src = extra[0]
    close = [g for g in GOLD if g[0] == src[0] and g[3] == src[3]]
    why = " (the row for it is there but another column is off)" if close else ""
    fail(f"❌ {len(extra)} row(s) are not right, for example source '{src[0]}'{why}; that is a comment, a disabled/ignored file, or a wrongly read field")
if missing:
    fail(f"❌ {len(missing)} of {len(GOLD)} scheduled items are missing, for example one from '{missing[0][0].split(':')[0] if missing[0][0].startswith('at:') else missing[0][0]}'")
print(f"✅ inventory.tsv lists all {len(GOLD)} scheduled items correctly")
PY
exit $?
