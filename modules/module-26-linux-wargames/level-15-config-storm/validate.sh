#!/bin/bash
# Every rendered/<svc>.conf byte-exact, drift.txt exact, template and live unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
if ! sha256sum -c --quiet .lm-state/sources.sum >/dev/null 2>&1; then
  echo "❌ template.conf or something in live/ was changed; they are the reference, restore them with 'reset'"; exit 1
fi
python3 - <<'PY'
import json, os, sys
t = json.load(open(".lm-state/truth.json"))
for s in t["services"]:
    p = "rendered/%s.conf" % s
    if not os.path.isfile(p):
        print("❌ %s is missing" % p); sys.exit(1)
    got = open(p, newline="").read(); exp = t["expected"][s]
    if got != exp:
        gl, el = got.split("\n"), exp.split("\n")
        bad = next((e for g, e in zip(gl + [None] * len(el), el) if g != e), None)
        if len(gl) != len(el) and bad is None: why = "has a different number of lines"
        else:
            key = (bad or "").split(" = ")[0].strip()
            why = "differs on the line for `%s`" % key if key else "differs"
            if "\r" in got: why = "contains a carriage return (CRLF from an env file?)"
        print("❌ %s %s" % (p, why)); sys.exit(1)
if not os.path.isfile("drift.txt"):
    print("❌ drift.txt does not exist"); sys.exit(1)
got = sorted(set(l.strip() for l in open("drift.txt", errors="replace") if l.strip()))
if got != t["drift"]:
    ex = [g for g in got if g not in t["drift"]]
    if ex: print("❌ drift.txt lists %s, whose live config only differs in comments or blank lines (or not at all)" % ex[0])
    else: print("❌ drift.txt is missing %d service(s) whose live config has real manual changes" % (len(t["drift"]) - len(got)))
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ all 12 rendered configs are exact and drift.txt lists exactly the services with real manual changes"
