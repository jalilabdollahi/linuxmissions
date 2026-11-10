#!/bin/bash
# 1. escalations.txt == the original file:line of the six dangerous rules
# 2. every active file in etc/sudoers.d passes `visudo -cf`
# 3. a small sudoers parser (inline python, expands Cmnd_Alias) finds no remaining way to
#    root: no ALL / shells / editors / pagers / find / tar, no wildcard arguments, no command
#    without argument list unless it is a root-owned wrapper, no script that ownership.txt
#    shows as writable by someone other than root
# 4. the safe rules are still granted, and each team still has a safe rule for its task
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -s escalations.txt ] || { echo "❌ escalations.txt is missing or empty"; exit 1; }
[ "$(sha256sum < ownership.txt)" = "$(cat .lm-state/own.sha)" ] || { echo "❌ ownership.txt was edited: it is the evidence, fix the rules"; exit 1; }
( cd etc && sha256sum sudoers ) | cmp -s - .lm-state/main.sha || { echo "❌ etc/sudoers was changed: only etc/sudoers.d/ should be fixed"; exit 1; }

sed -e 's/\r$//' -e "s#^$SANDBOX/##" -e 's#^\./##' escalations.txt | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u > .lm-state/got
LC_ALL=C sort -u .lm-state/expected > .lm-state/want
extra=$(comm -13 .lm-state/want .lm-state/got | head -1)
[ -z "$extra" ] || { echo "❌ escalations.txt lists $extra, which is not an escalation rule (file:line of the original rule, active files only)"; exit 1; }
have=$(comm -12 .lm-state/want .lm-state/got | wc -l); want=$(wc -l < .lm-state/want)
[ "$have" -eq "$want" ] || { echo "❌ escalations.txt names $have of $want dangerous rules"; exit 1; }

for f in etc/sudoers.d/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in *.*|*~) continue ;; esac
  if ! err=$(visudo -cf "$f" 2>&1); then echo "❌ visudo rejects $f: $(echo "$err" | head -1)"; exit 1; fi
done

res=$(python3 - "$(cat .lm-state/svc)" <<'PY'
import os, re, sys
svc = sys.argv[1]
D = "etc/sudoers.d"
own = {}
for line in open("ownership.txt"):
    if line.startswith("#") or not line.strip():
        continue
    mode, owner, group, path = line.split()
    own[path] = (mode, owner, group)

def logical_lines(path):
    out, cur = [], ""
    for raw in open(path):
        raw = raw.rstrip("\n")
        if raw.endswith("\\"):
            cur += raw[:-1]; continue
        cur += raw
        line = cur.strip(); cur = ""
        if not line or line.startswith("#"):
            continue
        out.append(line)
    return out

aliases, rules = {}, []
files = sorted(f for f in os.listdir(D) if "." not in f and not f.endswith("~"))
for f in files:
    for line in logical_lines(os.path.join(D, f)):
        m = re.match(r"Cmnd_Alias\s+(\w+)\s*=\s*(.*)$", line)
        if m:
            aliases[m.group(1)] = [c.strip() for c in m.group(2).split(",")]
            continue
        if re.match(r"(Defaults|User_Alias|Host_Alias|Runas_Alias|@|#)", line):
            continue
        m = re.match(r"(\S+)\s+(\S+)\s*=\s*(?:\(([^)]*)\)\s*)?(.*)$", line)
        if m:
            rules.append((f, m.group(1), m.group(3) or "root", m.group(4)))

TAGS = re.compile(r"^(?:(?:NO)?PASSWD|(?:NO)?EXEC|SETENV|NOSETENV|LOG_INPUT|NOLOG_INPUT|LOG_OUTPUT|NOLOG_OUTPUT|MAIL|NOMAIL)\s*:\s*")
def expand(cmds, depth=0):
    for c in cmds:
        c = c.strip()
        while TAGS.match(c):
            c = TAGS.sub("", c, count=1)
        if c in aliases and depth < 5:
            yield from expand(aliases[c], depth + 1)
        elif c:
            yield c

grants = []   # (who, root_possible, cmdline)
for f, who, runas, cmds in rules:
    rp = any(r.strip() in ("root", "ALL") or r.strip().startswith(("root:", "ALL:")) for r in re.split(r"[,:]", runas.split(":")[0])) if runas else True
    for c in expand(cmds.split(",")):
        if c.startswith("!"):
            continue
        grants.append((f, who, rp, c))

DANGER_BASE = {"all", "sh", "bash", "dash", "zsh", "su", "env", "less", "more", "most", "man", "vi", "vim", "view", "nano", "pico", "ed",
               "emacs", "find", "tar", "awk", "gawk", "mawk", "perl", "python", "python3", "ruby", "lua", "nmap", "ftp", "gdb", "git",
               "zip", "rsync", "cp", "mv", "tee", "dd", "chmod", "chown", "sed", "xargs", "ssh", "scp", "tcpdump", "strace", "systemd-run"}
def danger(cmdline):
    parts = cmdline.split(None, 1)
    cmd = parts[0]; args = parts[1].strip() if len(parts) > 1 else ""
    base = os.path.basename(cmd).lower()
    if cmd == "ALL" or base in DANGER_BASE:
        return "grants " + base
    if any(ch in args for ch in "*?["):
        return "has a wildcard argument"
    if base == "sudoedit":
        return "sudoedit without a file" if not args else None
    if cmd in own:
        mode, owner, group = own[cmd]
        if owner != "root" or mode[5] == "w" or mode[8] == "w":
            return "runs " + cmd + " which is not protected (owner " + owner + ", " + mode + ")"
        return None
    if not args:
        return "has no argument list, so any arguments are allowed"
    return None

bad = []
for f, who, rp, c in grants:
    if rp:
        why = danger(c)
        if why:
            bad.append((f, who, c, why))
if bad:
    f, who, c, why = bad[0]
    print("FAIL %d way(s) to root remain, for example in %s: %s %s (%s)" % (len(bad), f, who, c, why))
    sys.exit(0)

have = {(who, " ".join(c.split())) for f, who, rp, c in grants}
for line in open(".lm-state/safe"):
    who, c = line.rstrip("\n").split("|", 1)
    if (who, c) not in have:
        print("FAIL a rule that was fine is gone: %s %s" % (who, c)); sys.exit(0)

def team(who, test):
    return any(w == who and test(c) for f, w, rp, c in grants)
base = lambda c: os.path.basename(c.split()[0])
need = [
    ("%web",   lambda c: base(c) in ("tail", "cat", "journalctl") and "nginx" in c, "reading the nginx error log"),
    ("%dba",   lambda c: c == "sudoedit /etc/postgresql/16/main/postgresql.conf", "editing postgresql.conf"),
    ("%ops",   lambda c: c == "/usr/bin/systemctl restart %s.service" % svc, "restarting %s.service" % svc),
    ("%backup", lambda c: base(c) == "backup-home", "running the backup"),
    ("%dev",   lambda c: base(c) in ("tail", "cat", "journalctl") and svc in c, "reading the %s logs" % svc),
    ("%deploy", lambda c: base(c) == "deploy-release", "deploying a release"),
]
for who, test, what in need:
    if not team(who, test):
        print("FAIL %s lost the ability to do its job (%s): keep the task, remove the escalation" % (who, what)); sys.exit(0)
print("OK")
PY
)
case "$res" in
  OK) echo "✅ no rule leads to root any more, the safe rules and every team's task are intact, escalations documented"; exit 0 ;;
  FAIL*) echo "❌ ${res#FAIL }"; exit 1 ;;
  *) echo "❌ internal check failed: $(echo "$res" | tail -1)"; exit 1 ;;
esac
