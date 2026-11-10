#!/bin/bash
# Version Compare: 30 distinct Debian versions (epochs, ~pre-releases, +dfsg, ubuntu and bpo
# revisions) in random order. setup retries until `sort -V` really disagrees with dpkg, so the
# shortcut cannot pass.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm
python3 - <<'PY' || exit 1
import functools, random, subprocess, sys
r = random.Random()
def cmp(a, b):
    if subprocess.run(["dpkg", "--compare-versions", a, "lt", b]).returncode == 0: return -1
    if subprocess.run(["dpkg", "--compare-versions", a, "gt", b]).returncode == 0: return 1
    return 0
for attempt in range(50):
    bases = sorted({f"{r.randint(0, 3)}.{r.randint(0, 12)}" for _ in range(6)})
    pool = set()
    for b in bases:
        pool |= {b, f"{b}.{r.randint(1, 9)}", f"{b}~rc1", f"{b}~rc2", f"{b}~beta1", f"{b}+dfsg", f"{b}-1", f"{b}-2",
                 f"{b}-1ubuntu1", f"{b}-1ubuntu0.1", f"{b}-1~bpo12+1", f"{b}~rc1-1", f"{b}+git20260101-1", f"{b}-10", f"{b}-9"}
    pool = sorted(pool)
    r.shuffle(pool)
    vs = pool[:30]
    # epochs: re-label a few as 1: / 2: so old numbering wins over new
    for i in r.sample(range(30), 3):
        vs[i] = f"{r.randint(1, 2)}:{vs[i]}"
    if len(set(vs)) != 30: continue
    if any(cmp(a, b) == 0 for a in vs for b in vs if a != b): continue
    want = sorted(vs, key=functools.cmp_to_key(cmp))
    naive = subprocess.run(["sort", "-V"], input="\n".join(vs) + "\n", capture_output=True, text=True).stdout.split()
    if naive == want: continue
    if not any(":" in v for v in vs) or not any("~" in v for v in vs): continue
    open("versions.txt", "w").write("\n".join(vs) + "\n")
    open(".lm/order.txt", "w").write("\n".join(want) + "\n")
    break
else:
    sys.exit("could not build a version set")
PY
