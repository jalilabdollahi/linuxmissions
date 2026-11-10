#!/bin/bash
# Parse etc/aliases the way aliases(5) defines it (continuation lines, case-insensitive names,
# :include:), compare the map with the expected one, look for mkhan in both files, and check
# that aliases.db is newer than the file and holds exactly the same table.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - "$SANDBOX" <<'PY'
import os, re, sys

sb = sys.argv[1]
A, L, DB = f"{sb}/etc/aliases", f"{sb}/etc/oncall.list", f"{sb}/etc/aliases.db"
for p in (A, L):
    if not os.path.isfile(p):
        print(f"❌ {p.replace(sb + '/', '')} is missing")
        sys.exit(1)

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def parse(path):
    logical = []
    gap = True                      # previous physical line was blank, a comment, or the start
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith("#"):
            gap = True
            continue
        was_gap, gap = gap, False
        if raw[0] in " \t":
            if not logical or was_gap:
                fail(f"etc/aliases line {n} is indented but continues no alias: a recipient line was left behind")
            logical[-1][1] += " " + raw.strip()
        else:
            logical.append([n, raw.strip()])
    table = {}
    for n, text in logical:
        if ":" not in text:
            fail(f"etc/aliases line {n} is not 'name: recipients'")
        name, value = text.split(":", 1)
        rec = [r.strip().lower() for r in value.split(",") if r.strip()]
        if not rec:
            fail(f"etc/aliases line {n}: alias '{name.strip()}' has no recipient")
        if name.strip().lower() in table:
            fail(f"etc/aliases line {n}: alias '{name.strip()}' is defined twice")
        table[name.strip().lower()] = rec
    return table

def addresses(path):
    out = []
    for raw in open(path).read().splitlines():
        if raw.lstrip().startswith("#"):
            continue
        out += [t.strip().lower() for t in raw.split(",") if t.strip()]
    return out

orig = open(f"{sb}/.lm-state/aliases.orig").read()
if open(A).read() == orig and open(L).read() == open(f"{sb}/.lm-state/oncall.orig").read():
    fail("nothing has been changed yet")

table = parse(A)
inc = ":include:" + L
want = {
    "postmaster": ["root"], "mailer-daemon": ["postmaster"], "abuse": ["postmaster"],
    "root": [inc], "dev-team": ["alice@corp.example", "mkhanna@corp.example", "bob@corp.example"],
    "ops": ["alice@corp.example"], "support": [inc],
    "security": ["secops@corp.example", "soc-oncall@corp.example"],
}
for text, label in ((open(A).read(), "etc/aliases"), (open(L).read(), "etc/oncall.list")):
    for tok in re.findall(r"[A-Za-z0-9._+-]+(?:@[A-Za-z0-9.-]+)?", "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))):
        if tok.split("@")[0].lower() == "mkhan":
            fail(f"mkhan is still in {label} ({tok}), in any capitalisation")
if "root" not in table or table["root"] != [inc]:
    fail("root does not deliver to the on-call list yet (expected the :include: of the full path of etc/oncall.list)")
for name in sorted(set(want) | set(table)):
    if name not in table:
        fail(f"the alias '{name}' is missing" + (" (a recipient line was deleted along with its alias?)" if name in want else ""))
    if name not in want:
        fail(f"the alias '{name}' should not exist (an alias with no recipients left is removed)")
    if sorted(table[name]) != sorted(want[name]):
        fail(f"alias '{name}' has recipients {', '.join(table[name])}, expected {', '.join(want[name])}")

le = sorted(set(addresses(L)))
if le != ["alice@corp.example", "carol@corp.example", "mkhanna@corp.example"]:
    fail("etc/oncall.list should hold exactly alice, carol and mkhanna after the change, found: " + ", ".join(le))
for c in [l for l in orig.splitlines() if l.startswith("#")]:
    if c not in open(A).read().splitlines():
        fail(f"a comment of etc/aliases was lost: {c[:40]}")
if "# on-call rotation, one address per line" not in open(L).read():
    fail("the comment of etc/oncall.list was lost")

if not os.path.isfile(DB):
    fail("etc/aliases.db does not exist: rebuild it")
if os.stat(DB).st_mtime_ns <= os.stat(A).st_mtime_ns:
    fail("etc/aliases.db is older than etc/aliases: run newaliases after the last edit")
db = {}
for line in open(DB).read().splitlines():
    k, _, v = line.partition("\t")
    db[k] = sorted(x.lower() for x in v.split(","))
if db != {k: sorted(v) for k, v in table.items()}:
    fail("etc/aliases.db does not match etc/aliases: rebuild it with newaliases (and read its warnings)")
print("✅ root goes to the on-call list, security exists, mkhan is gone everywhere, and the database is rebuilt")
PY
