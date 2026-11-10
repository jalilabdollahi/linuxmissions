#!/bin/bash
# bastion-1's /var/log/auth.log from 22:00 to 07:00 (Ubuntu rsyslog format,
# "Nov  9" with two spaces). Overnight SSH brute force from many IPs. An IP is
# compromised when at least 5 failed password attempts from it come before an
# Accepted login from it; the answer line is "ip user-who-logged-in".
# Planned per setup (IPs, users, counts, times random):
#  - 2-3 compromised IPs; for one of them the 5 failures are only reached by
#    counting "message repeated N times: [ Failed password ... ]" lines;
#  - an IP with 4 failures then a login (a user mistyping) - not compromised;
#  - the office IP logs in first and only fails afterwards - not compromised;
#  - "Failed password for invalid user X from IP" has two more words than
#    "Failed password for root from IP", so field numbers shift.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/log .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
rnd = random.Random(sys.argv[1])
HOST = "bastion-1"
T0 = 22 * 3600            # seconds from Nov 9 00:00
T1 = 31 * 3600            # Nov 10 07:00
ev = []                   # (time, seq, program, message)
seq = 0
def log(t, prog, msg):
    global seq
    seq += 1
    ev.append((t, seq, prog, msg))

used_ip = set()
def new_ip(prefixes=("45.148.10.", "141.98.11.", "193.32.162.", "218.92.0.", "61.177.172.", "180.101.88.", "92.255.85.", "103.149.28.", "185.224.128.")):
    while True:
        ip = rnd.choice(prefixes) + str(rnd.randint(2, 254))
        if ip not in used_ip:
            used_ip.add(ip)
            return ip
pids = iter(rnd.sample(range(20000, 99999), 4000))
port = lambda: rnd.randint(32768, 65535)
BAD_USERS = ["admin", "test", "oracle", "ubuntu1", "user", "ftpuser", "postgres", "git", "pi", "support", "guest", "hadoop"]
REAL = {"deploy": 1001, "backup": 1002, "jenkins": 1003, "ops": 1004}

def attempt_conn(t, ip, user, tries, repeat=True):
    """One TCP connection with `tries` password attempts for the same user.
    Returns the time after the connection and the number of failures logged."""
    pid, p = next(pids), port()
    invalid = user not in REAL and user != "root"
    if invalid:
        log(t, f"sshd[{pid}]", f"Invalid user {user} from {ip} port {p}")
        log(t + 0.2, f"sshd[{pid}]", "pam_unix(sshd:auth): check pass; user unknown")
        log(t + 0.2, f"sshd[{pid}]", f"pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost={ip} ")
    else:
        log(t + 0.2, f"sshd[{pid}]", f"pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost={ip}  user={user}")
    who = f"invalid user {user}" if invalid else user
    t += rnd.uniform(1.5, 3.5)
    log(t, f"sshd[{pid}]", f"Failed password for {who} from {ip} port {p} ssh2")
    if tries > 1:
        if repeat:
            t += rnd.uniform(4, 12) * (tries - 1)
            log(t, f"sshd[{pid}]", f"message repeated {tries - 1} times: [ Failed password for {who} from {ip} port {p} ssh2]")
        else:
            for _ in range(tries - 1):
                t += rnd.uniform(2, 6)
                log(t, f"sshd[{pid}]", f"Failed password for {who} from {ip} port {p} ssh2")
    if tries >= 6:
        log(t + 0.1, f"sshd[{pid}]", f"error: maximum authentication attempts exceeded for {who} from {ip} port {p} ssh2 [preauth]")
        log(t + 0.1, f"sshd[{pid}]", f"Disconnecting {'invalid' if invalid else 'authenticating'} user {user} {ip} port {p}: Too many authentication failures [preauth]")
    else:
        log(t + 0.5, f"sshd[{pid}]", f"Connection closed by {'invalid' if invalid else 'authenticating'} user {user} {ip} port {p} [preauth]")
    return t + rnd.uniform(1, 20), tries

def accepted(t, ip, user, method="password"):
    pid, p = next(pids), port()
    if method == "password":
        log(t, f"sshd[{pid}]", f"Accepted password for {user} from {ip} port {p} ssh2")
    else:
        log(t, f"sshd[{pid}]", f"Accepted publickey for {user} from {ip} port {p} ssh2: ED25519 SHA256:{''.join(rnd.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/') for _ in range(43))}")
    log(t + 0.05, f"sshd[{pid}]", f"pam_unix(sshd:session): session opened for user {user}(uid={REAL[user]}) by {user}(uid=0)")
    log(t + 0.1, "systemd-logind[688]", f"New session {rnd.randint(100, 999)} of user {user}.")
    end = t + rnd.uniform(30, 900)
    log(end, f"sshd[{pid}]", f"Received disconnect from {ip} port {p}:11: disconnected by user")
    log(end, f"sshd[{pid}]", f"pam_unix(sshd:session): session closed for user {user}")

def burst(ip, t, total, users, repeat_bias=0.5, max_tries=6):
    """total failed attempts from ip starting at t, spread over connections."""
    left = total
    while left > 0:
        n = min(left, rnd.randint(1, max_tries))
        t, _ = attempt_conn(t, ip, rnd.choice(users), n, rnd.random() < repeat_bias)
        left -= n
        t += rnd.uniform(5, 120)
    return t

# Background brute force that never gets in.
for _ in range(rnd.randint(14, 22)):
    ip = new_ip()
    burst(ip, rnd.uniform(T0, T1 - 7200), rnd.randint(3, 120), ["root"] + rnd.sample(BAD_USERS, 4), max_tries=rnd.choice([1, 3, 6]))

answer = []
# Compromised 1 (and maybe 2): many failures, then in.
for _ in range(rnd.randint(1, 2)):
    ip, user = new_ip(), rnd.choice(["deploy", "backup", "jenkins"])
    t = burst(ip, rnd.uniform(T0, T1 - 14400), rnd.randint(12, 90), ["root", user, user] + rnd.sample(BAD_USERS, 3))
    accepted(t + rnd.uniform(20, 300), ip, user)
    answer.append((ip, user))
# Compromised, exactly 5 failures: one plain line + "message repeated 4 times",
# or two lines + "message repeated 3 times" - 2 or 3 lines on screen.
ip, user = new_ip(), rnd.choice(["deploy", "backup", "jenkins"])
t = rnd.uniform(T0, T1 - 10800)
if rnd.random() < 0.5:
    t, _ = attempt_conn(t, ip, user, 5, True)
else:
    t, _ = attempt_conn(t, ip, "root", 1, True)
    t, _ = attempt_conn(t + 40, ip, user, 4, True)
accepted(t + rnd.uniform(30, 600), ip, user)
answer.append((ip, user))
# Not compromised: 4 failures (one line + "repeated 3 times"), then a login: a colleague mistyping.
ip = "10.20." + str(rnd.randint(1, 9)) + "." + str(rnd.randint(10, 250))
used_ip.add(ip)
t, _ = attempt_conn(rnd.uniform(T0, T1 - 7200), ip, "ops", 4, True)
accepted(t + rnd.uniform(5, 30), ip, "ops")
# Not compromised: the office NAT logs in first, then fails a lot (an expired key script).
office = "198.51.100." + str(rnd.randint(2, 254))
used_ip.add(office)
ta = rnd.uniform(T0 + 600, T0 + 7200)
accepted(ta, office, "deploy", "publickey")
burst(office, ta + rnd.uniform(3600, 10800), rnd.randint(6, 15), ["deploy"])
# Ordinary key logins.
for _ in range(rnd.randint(4, 8)):
    accepted(rnd.uniform(T0, T1), "10.20." + str(rnd.randint(1, 9)) + "." + str(rnd.randint(10, 250)), rnd.choice(["ops", "jenkins", "backup"]), "publickey")
# cron and sudo noise
t = T0 + rnd.uniform(0, 600)
while t < T1:
    pid = next(pids)
    log(t, f"CRON[{pid}]", "pam_unix(cron:session): session opened for user root(uid=0) by root(uid=0)")
    log(t + 0.4, f"CRON[{pid}]", "pam_unix(cron:session): session closed for user root")
    t += 3600 if rnd.random() < 0.3 else 600
for _ in range(rnd.randint(2, 4)):
    t = rnd.uniform(T0, T1)
    log(t, "sudo", "     ops : TTY=pts/0 ; PWD=/home/ops ; USER=root ; COMMAND=/usr/bin/journalctl -u ssh")
    log(t, "sudo", "pam_unix(sudo:session): session opened for user root(uid=0) by ops(uid=1004)")

ev.sort(key=lambda e: (int(e[0]), e[1]))
with open("var/log/auth.log", "w") as fh:
    for t, _, prog, msg in ev:
        t = int(t)
        day = 9 + t // 86400
        s = t % 86400
        fh.write(f"Nov {day:2d} {s // 3600:02d}:{s // 60 % 60:02d}:{s % 60:02d} {HOST} {prog}: {msg}\n")
PY
cksum var/log/auth.log > .lm-state/auth.sum
