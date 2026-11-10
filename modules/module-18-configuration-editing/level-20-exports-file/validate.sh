#!/bin/bash
# Parse etc/exports with the rules of exports(5) (a space before "(" starts a new, world-wide
# client), check each path's effective clients and options, the untouched backup line and comments,
# and finally what the export table shows (exportfs -v), which only changes with exportfs -r.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import re, subprocess, sys

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def parse(text):
    table = {}
    buf = ""
    for raw in text.splitlines():
        if raw.endswith("\\"):
            buf += raw[:-1]
            continue
        line = buf + raw
        buf = ""
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        toks = line.split()
        clients = table.setdefault(toks[0], [])
        for tok in toks[1:] or ["*"]:
            m = re.match(r"^([^(]*)(?:\((.*)\))?$", tok)
            opts = set(x for x in (m.group(2) or "").split(",") if x)
            clients.append((m.group(1) or "*", opts))
    return table

cur_text = open(f"{sb}/etc/exports").read()
orig_text = open(f"{sb}/.lm-state/exports.orig").read()
if cur_text == orig_text:
    fail("etc/exports has not been changed yet")
table = parse(cur_text)

def mode(opts):
    return "rw" if "rw" in opts else "ro"

b = table.get("/srv/builds")
if not b:
    fail("/srv/builds is no longer exported")
for client, opts in b:
    if client != "10.20.0.0/24":
        fail(f"/srv/builds is still exported to '{client}' (with {mode(opts)}): only 10.20.0.0/24 may have it")
    if mode(opts) != "rw":
        fail("/srv/builds is exported to the subnet read-only: the build farm must be able to write")
if len(b) != 1:
    fail("/srv/builds lists the subnet more than once")
i = table.get("/srv/iso")
if not i:
    fail("/srv/iso is no longer exported")
if [(c, mode(o)) for c, o in i] != [("*", "ro")]:
    fail("/srv/iso must be exported read-only to everyone (*) and nobody else; found " + ", ".join(f"{c}({mode(o)})" for c, o in i))
for path, clients in table.items():
    for c, o in clients:
        if "no_root_squash" in o:
            fail(f"no_root_squash is still set on {path} for {c}")
want_backup = [l for l in orig_text.splitlines() if l.startswith("/srv/backup")]
if [l for l in cur_text.splitlines() if l.startswith("/srv/backup")] != want_backup:
    fail("the /srv/backup line was changed: it must stay as it was")
for c in [l for l in orig_text.splitlines() if l.startswith("#")]:
    if c not in cur_text.splitlines():
        fail(f"a comment was lost: {c[:45]}")

# The kernel's export table, as exportfs -v prints it.
out = subprocess.run([f"{sb}/bin/exportfs", "-v"], capture_output=True, text=True).stdout.splitlines()
live, path = {}, None
for line in out:
    if not line.startswith("\t") and "\t" in line:
        path, rest = line.split("\t", 1)
        path = path.strip()
    elif not line.startswith("\t"):
        path, rest = line.strip(), None
    else:
        rest = line.strip()
    if rest:
        m = re.match(r"^(\S+?)\((.*)\)$", rest)
        live.setdefault(path, []).append((m.group(1), set(m.group(2).split(","))))
lb, li = live.get("/srv/builds", []), live.get("/srv/iso", [])
if [c for c, _ in lb] != ["10.20.0.0/24"] or "rw" not in lb[0][1] or [c for c, _ in li] != ["<world>"] or "ro" not in li[0][1] \
        or any("no_root_squash" in o for lst in live.values() for _, o in lst):
    fail("etc/exports is right, but exportfs -v still shows the old table: apply the change with exportfs -r")
print("✅ builds is rw for 10.20.0.0/24 only, iso is ro for everyone, no_root_squash is gone, and the table is applied")
PY
