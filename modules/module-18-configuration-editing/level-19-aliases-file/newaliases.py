#!/usr/bin/env python3
"""Level-local stand-in for Postfix's newaliases: reads etc/aliases in the sandbox that holds
this bin/ directory, reports bad lines like postalias does (as warnings, exit status 0) and
writes the lookup table etc/aliases.db (one "name<TAB>recipient,recipient" line per alias)."""
import os, sys

ROOT = os.environ.get("LM_ROOT") or os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SRC = os.path.join(ROOT, "etc/aliases")
DB = SRC + ".db"

if sys.argv[1:]:
    print("newaliases: this stand-in takes no arguments", file=sys.stderr)
    sys.exit(1)
if not os.path.isfile(SRC):
    print(f"newaliases: fatal: open {SRC}: No such file or directory", file=sys.stderr)
    sys.exit(1)

logical = []                      # [lineno, text] with continuation lines joined
gap = True                        # the previous physical line was blank, a comment, or the start
for n, raw in enumerate(open(SRC).read().splitlines(), 1):
    if not raw.strip() or raw.lstrip().startswith("#"):
        gap = True
        continue
    was_gap, gap = gap, False
    if raw[0] in " \t":
        if not logical or was_gap:
            print(f"newaliases: warning: {SRC}, line {n}: expected format: key: value", file=sys.stderr)
            continue
        logical[-1][1] += " " + raw.strip()
    else:
        logical.append([n, raw.strip()])

table = {}
for n, text in logical:
    if ":" not in text:
        print(f"newaliases: warning: {SRC}, line {n}: expected format: key: value", file=sys.stderr)
        continue
    name, value = text.split(":", 1)
    name = name.strip().lower()
    recipients = [r.strip() for r in value.split(",") if r.strip()]
    if not name or not recipients:
        print(f"newaliases: warning: {SRC}, line {n}: alias '{name}' has no recipients", file=sys.stderr)
        continue
    if name in table:
        print(f"newaliases: warning: {SRC}, line {n}: duplicate alias name {name}", file=sys.stderr)
        continue
    table[name] = recipients

with open(DB, "w") as f:
    for name in sorted(table):
        f.write(name + "\t" + ",".join(table[name]) + "\n")
