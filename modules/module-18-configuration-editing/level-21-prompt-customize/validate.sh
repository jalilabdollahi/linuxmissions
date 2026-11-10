#!/bin/bash
# Start a real interactive bash with home/.bashrc from home/work/api, feed it commands that end
# with a known exit status and print the expanded prompt (${PS1@P}) after each one.
SANDBOX="$1"
cd "$SANDBOX/home/work/api" || exit 1

python3 - "$SANDBOX" <<'PY'
import os, pwd, re, socket, subprocess, sys

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rc = f"{sb}/home/.bashrc"
user = pwd.getpwuid(os.getuid()).pw_name
host = socket.gethostname().split(".")[0]
base = f"{user}@{host}:~/work/api"
histsize = open(f"{sb}/.lm-state/histsize").read().strip()

script = r'''
true
printf '<<A[%s]A>>\n' "${PS1@P}"
false
printf '<<B[%s]B>>\n' "${PS1@P}"
(exit 130)
printf '<<C[%s]C>>\n' "${PS1@P}"
false; true
printf '<<D[%s]D>>\n' "${PS1@P}"
alias ll gs
echo "<<E[$EDITOR $HISTSIZE]E>>"
'''
env = {"HOME": f"{sb}/home", "PATH": os.environ.get("PATH", "/usr/bin:/bin"), "TERM": "xterm", "USER": user}
r = subprocess.run(["bash", "--noprofile", "--rcfile", rc, "-i"], input=script.encode(),
                   capture_output=True, env=env, cwd=f"{sb}/home/work/api", timeout=20)
out = r.stdout
def grab(tag):
    m = re.search(rb"<<%s\[(.*?)\]%s>>" % (tag.encode(), tag.encode()), out, re.S)
    if not m:
        fail("bash did not print the prompt: is home/.bashrc still loading? " + r.stderr.decode(errors="replace").strip().splitlines()[-1][:80] if r.stderr.strip() else "bash did not print the prompt")
    return m.group(1).decode(errors="replace")

def analyse(p, label):
    """-> (printable text, [colour of every printable char])"""
    inside, color, text, cols, i = False, None, "", [], 0
    while i < len(p):
        ch = p[i]
        if ch == "\x01":
            inside = True; i += 1; continue
        if ch == "\x02":
            inside = False; i += 1; continue
        if ch == "\x1b":
            if not inside:
                fail(f"after {label} the prompt has a colour escape that is not wrapped in \\[ and \\]: readline would miscount the width")
            m = re.match(r"\x1b\[([0-9;]*)m", p[i:])
            if m:
                params = m.group(1).split(";")
                if m.group(1) in ("", "0"):
                    color = None
                elif "31" in params or "91" in params or params[:2] == ["38", "5"] and params[-1] in ("196", "9", "1"):
                    color = "red"
                else:
                    color = color if params == ["1"] else "other"
                i += len(m.group(0)); continue
        if inside:
            i += 1; continue
        text += ch; cols.append(color); i += 1
    return text, cols

for tag, label, code in (("A", "`true`", 0), ("B", "`false`", 1), ("C", "`(exit 130)`", 130), ("D", "`false; true`", 0)):
    p = grab(tag)
    text, cols = analyse(p, label)
    if not text.startswith(base):
        fail(f"after {label} the prompt reads '{text.strip()}', expected it to start with {base}")
    rest = text[len(base):]
    if code == 0:
        if re.search(r"\d", rest):
            fail(f"after {label} (exit status 0) the prompt shows a number: '{text.strip()}'; the code appears only when it is not zero")
    else:
        m = re.search(r"(?<!\d)%d(?!\d)" % code, rest)
        if not m:
            fail(f"after {label} (exit status {code}) the prompt shows no exit code: '{text.strip()}'")
        pos = len(base) + m.start()
        if any(c != "red" for c in cols[pos:pos + len(str(code))]):
            fail(f"the exit code {code} is not printed in red")
        if not rest.strip().endswith(("$", "#")):
            fail("the prompt character ($) is missing at the end of the prompt")

E = grab("E")
if E != f"vim {histsize}":
    fail(f"the rest of home/.bashrc changed: EDITOR / HISTSIZE are '{E}', expected 'vim {histsize}'")
err = r.stderr.decode(errors="replace")
if "ll='ls -alF'" not in out.decode(errors="replace") + err or "gs='git status -sb'" not in out.decode(errors="replace") + err:
    fail("the aliases ll and gs of home/.bashrc are gone")
print("✅ the prompt shows user@host:dir, the exit code in red only on failure, and every escape is wrapped")
PY
