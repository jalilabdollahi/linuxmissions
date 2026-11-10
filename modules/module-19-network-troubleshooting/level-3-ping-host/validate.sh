#!/bin/bash
# Reads the six summaries and compares lossy.txt / jittery.txt with the sets
# they imply.
SANDBOX="$1"

for f in lossy.txt jittery.txt; do
  if [ ! -f "$SANDBOX/$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

python3 - "$SANDBOX" <<'PY'
import glob, os, re, sys
sb = sys.argv[1]
lossy, jittery, sites = set(), set(), set()
for path in glob.glob(os.path.join(sb, "pings", "*.txt")):
    site = os.path.basename(path)[:-4]
    sites.add(site)
    text = open(path).read()
    loss = float(re.search(r"([\d.]+)% packet loss", text).group(1))
    if loss > 2:
        lossy.add(site)
    m = re.search(r"^rtt min/avg/max/mdev = [\d.]+/[\d.]+/[\d.]+/([\d.]+) ms", text, re.M)
    if m and float(m.group(1)) > 20:
        jittery.add(site)

def read(name):
    words = set()
    for line in open(os.path.join(sb, name), encoding="utf-8", errors="replace"):
        w = line.strip().replace("\r", "")
        if w:
            words.add(w[:-4] if w.endswith(".txt") else w)
    return words

for name, want in (("lossy.txt", lossy), ("jittery.txt", jittery)):
    got = read(name)
    unknown = got - sites
    if unknown:
        print(f"❌ {name}: {sorted(unknown)[0]} is not a site name (use the file names in pings/ without .txt)")
        sys.exit(1)
    if got != want:
        extra, missing = len(got - want), len(want - got)
        what = "packet loss above 2 %" if name == "lossy.txt" else "an mdev above 20 ms"
        if extra:
            print(f"❌ {name} lists {extra} site(s) that do not have {what}")
        else:
            print(f"❌ {name} is missing {missing} site(s) with {what}")
        sys.exit(1)
print(f"✅ lossy: {', '.join(sorted(lossy))}; jittery: {', '.join(sorted(jittery)) or 'none'}")
PY
