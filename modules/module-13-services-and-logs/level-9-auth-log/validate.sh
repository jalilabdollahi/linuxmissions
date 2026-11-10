#!/bin/bash
# compromised.txt: "ip user" for every IP that had at least 5 failed password
# attempts (each "message repeated N times: [ Failed password ...]" line is N
# attempts) before an Accepted login from the same IP; user = who logged in.
# Order doesn't matter. Recomputed from var/log/auth.log.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/auth.sum ] || ! cksum var/log/auth.log 2>/dev/null | cmp -s - .lm-state/auth.sum; then
  echo "❌ var/log/auth.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f compromised.txt ]; then
  echo "❌ compromised.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import re, sys
from collections import Counter

fails, fails_plain, logins, failed_users = Counter(), Counter(), [], {}
exp, plain_exp, any_order = set(), set(), set()
for line in open("var/log/auth.log", encoding="utf-8"):
    if " sshd[" not in line:
        continue
    m = re.search(r"(?:message repeated (\d+) times: \[ )?Failed password for (?:invalid user )?(\S+) from (\S+) port", line)
    if m:
        n = int(m[1]) if m[1] else 1
        fails[m[3]] += n
        fails_plain[m[3]] += 1
        failed_users.setdefault(m[3], set()).add(m[2])
        continue
    m = re.search(r"Accepted \S+ for (\S+) from (\S+) port", line)
    if m:
        user, ip = m[1], m[2]
        logins.append((ip, user))
        if fails[ip] >= 5:
            exp.add((ip, user))
        if fails_plain[ip] >= 5:
            plain_exp.add((ip, user))

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows = [l.split() for l in open("compromised.txt", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
if any(len(r) != 2 for r in rows):
    fail("every line must be 'ip user', e.g. '203.0.113.9 deploy'")
got = {tuple(r) for r in rows}
if got == exp and len(rows) == len(exp):
    print("✅ compromised: " + ", ".join(f"{u}@{ip}" for ip, u in sorted(exp)) + ". Lock those accounts and rotate their passwords")
    sys.exit(0)
if not got:
    fail("compromised.txt is empty, but some brute force did succeed")
if len(rows) != len(got):
    fail("compromised.txt lists the same line twice")

# Final failure totals per IP, for the diagnostics.
login_ips = {ip for ip, _ in logins}
exp_ips = {ip for ip, _ in exp}
for ip, user in sorted(got):
    if ip not in fails and ip not in login_ips:
        fail(f"{ip} doesn't appear in the sshd lines of auth.log")
    if ip not in login_ips:
        fail(f"{ip} failed a lot but never logged in: no Accepted line for it")
    if ip not in exp_ips:
        if fails[ip] >= 5:
            fail(f"{ip} logged in before its failed attempts, not after: that's not a brute force that worked")
        fail(f"{ip} had only {fails[ip]} failed attempts before logging in; the threshold is 5")
    users = {u for i, u in exp if i == ip}
    if user not in users:
        if user in failed_users.get(ip, set()) or user == "root":
            fail(f"{ip} tried {user}, but the account that got in is a different one: take the user from the Accepted line")
        fail(f"{ip} logged in as {', '.join(sorted(users))}, not as {user}")
missing = exp - got
if missing & (exp - plain_exp):
    fail("an IP is missing whose failures are partly summarised as 'message repeated N times: [ Failed password ... ]': such a line counts as N attempts")
fail(f"{len(missing)} compromised IP(s) missing")
PY
