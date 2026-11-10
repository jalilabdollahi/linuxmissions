#!/bin/bash
# Nobody Can SSH In as ops. sysroot/ has four independent causes: ops' shell does not exist
# (and is not in /etc/shells), /etc/nologin exists, the shadow account-expiry field is in the
# past, and sshd StrictModes rejects the key because of modes (home group-writable, .ssh and
# authorized_keys too open). auth.log shows the first three kinds and the .ssh/authorized_keys
# refusals but not the home directory. Decoys: other users with legitimate nologin shell and
# expiry. bin/usermod and bin/chage are the shared accounts mock pointed at sysroot/.
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/accounts" && pwd)"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p bin .lm-state sysroot/etc sysroot/usr/bin sysroot/usr/sbin sysroot/var/log sysroot/home
cp "$MOCKS/accounts-mock" bin/accounts-mock
for t in usermod chage; do
  cat > bin/$t <<WEOF
#!/bin/bash
# $t (accounts mock): works on the captured server in sysroot/, not on this system.
HERE=\$(cd "\$(dirname "\$(readlink -f "\$0")")" && pwd)
exec env LM_ROOT="\$(dirname "\$HERE")/sysroot" "\$HERE/accounts-mock" $t "\$@"
WEOF
  chmod +x bin/$t
done
chmod +x bin/accounts-mock
python3 - <<'PYEOF'
import os, random, time
R = random.SystemRandom()
S = "sysroot"
def h(): return "$6$" + "".join(R.choice("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./") for _ in range(8)) + "$" + "".join(R.choice("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./") for _ in range(86))
today = int(time.time() // 86400)
badshell = R.choice(["/usr/bin/zsh", "/usr/local/bin/bash5", "/bin/ksh93", "/usr/bin/fish"])
expired = today - R.randrange(20, 300)
home_mode = R.choice([0o775, 0o777, 0o770]); ssh_mode = R.choice([0o755, 0o750, 0o770]); ak_mode = R.choice([0o664, 0o644, 0o660])
users = [("root", 0, 0, "root", "/root", "/bin/bash"), ("deploy", 1000, 1000, "Deploy", "/home/deploy", "/bin/bash"),
         ("ops", 1001, 1001, "Ops team", "/home/ops", badshell), ("backup", 34, 34, "backup", "/var/backups", "/usr/sbin/nologin"),
         ("contractor", 1002, 1002, "Temp contractor", "/home/contractor", "/bin/bash")]
with open(S + "/etc/passwd", "w") as f:
    for n, u, g, c, hm, sh in users: f.write("%s:x:%d:%d:%s:%s:%s\n" % (n, u, g, c, hm, sh))
with open(S + "/etc/shadow", "w") as f:
    for n, u, g, c, hm, sh in users:
        if n == "backup": f.write("backup:*:%d:0:99999:7:::\n" % (today - 400))
        elif n == "ops": f.write("ops:%s:%d:0:99999:7::%d:\n" % (h(), today - R.randrange(30, 200), expired))
        elif n == "contractor": f.write("contractor:%s:%d:0:99999:7::%d:\n" % (h(), today - 500, today - 60))
        else: f.write("%s:%s:%d:0:99999:7:::\n" % (n, h(), today - R.randrange(30, 300)))
open(S + "/etc/shells", "w").write("# /etc/shells: valid login shells\n/bin/sh\n/bin/bash\n/usr/bin/bash\n/bin/rbash\n/usr/bin/rbash\n/usr/bin/sh\n/bin/dash\n/usr/bin/dash\n")
for b in ("bash", "sh", "dash", "rbash"):
    p = S + "/usr/bin/" + b; open(p, "w").write("#!/bin/sh\n"); os.chmod(p, 0o755)
p = S + "/usr/sbin/nologin"; open(p, "w").write("#!/bin/sh\n"); os.chmod(p, 0o755)
if not os.path.lexists(S + "/bin"): os.symlink("usr/bin", S + "/bin")
open(S + "/etc/nologin", "w").write("System is being repaired. Back soon.\n")
for u in ("deploy", "ops", "contractor"):
    os.makedirs(S + "/home/%s/.ssh" % u, exist_ok=True)
    k = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI" + "".join(R.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(38)) + " %s@workstation\n" % u
    open(S + "/home/%s/.ssh/authorized_keys" % u, "w").write(k)
    os.chmod(S + "/home/%s/.ssh/authorized_keys" % u, 0o600); os.chmod(S + "/home/%s/.ssh" % u, 0o700); os.chmod(S + "/home/%s" % u, 0o755)
os.chmod(S + "/home/ops/.ssh/authorized_keys", ak_mode); os.chmod(S + "/home/ops/.ssh", ssh_mode); os.chmod(S + "/home/ops", home_mode)
# auth.log
t0 = time.time() - 3600 * R.randrange(3, 30)
def ts(dt): return time.strftime("%b %e %H:%M:%S", time.localtime(t0 + dt))
ip = lambda: "10.%d.%d.%d" % (R.randrange(0, 255), R.randrange(0, 255), R.randrange(2, 250))
pid = lambda: R.randrange(500, 9000)
host = R.choice(["rescue-web", "srv-app"])
ev = []
def add(dt, msg): ev.append((dt, "%s %s %s" % (ts(dt), host, msg)))
d = 0
def step(): 
    global d; d += R.randrange(40, 600); return d
p = pid(); ipa = ip()
add(step(), "sshd[%d]: Accepted publickey for deploy from %s port %d ssh2: ED25519 SHA256:%s" % (p, ip(), R.randrange(30000, 60000), "".join(R.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(10))))
add(step(), "sshd[%d]: Failed password for invalid user admin from %s port %d ssh2" % (pid(), ip(), R.randrange(30000, 60000)))
p = pid()
add(step(), "sshd[%d]: pam_nologin(sshd:account): access denied for user ops: /etc/nologin exists" % p)
add(d + 1, "sshd[%d]: fatal: Access denied for user ops by PAM account configuration [preauth]" % p)
p = pid()
add(step(), "sshd[%d]: User ops not allowed because shell %s does not exist" % (p, badshell))
add(step(), "CRON[%d]: pam_unix(cron:session): session opened for user root(uid=0) by (uid=0)" % pid())
p = pid()
add(step(), "sshd[%d]: pam_unix(sshd:account): account ops has expired (account expired)" % p)
add(d + 1, "sshd[%d]: fatal: Access denied for user ops by PAM account configuration [preauth]" % p)
add(step(), "sshd[%d]: Failed password for invalid user test from %s port %d ssh2" % (pid(), ip(), R.randrange(30000, 60000)))
p = pid()
add(step(), "sshd[%d]: Authentication refused: bad ownership or modes for directory /home/ops/.ssh" % p)
add(d + 1, "sshd[%d]: Connection closed by authenticating user ops %s port %d [preauth]" % (p, ip(), R.randrange(30000, 60000)))
p = pid()
add(step(), "sshd[%d]: Authentication refused: bad ownership or modes for file /home/ops/.ssh/authorized_keys" % p)
add(step(), "sshd[%d]: Accepted publickey for deploy from %s port %d ssh2: ED25519 SHA256:%s" % (pid(), ip(), R.randrange(30000, 60000), "".join(R.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(10))))
ev.sort()
open(S + "/var/log/auth.log", "w").write("".join(l + "\n" for _, l in ev))
open(".lm-state/today", "w").write(str(today))
PYEOF
cp sysroot/etc/passwd .lm-state/passwd0; cp sysroot/etc/shadow .lm-state/shadow0; cp sysroot/etc/shells .lm-state/shells0
cp sysroot/home/ops/.ssh/authorized_keys .lm-state/ak0
cksum bin/accounts-mock > .lm-state/sums
