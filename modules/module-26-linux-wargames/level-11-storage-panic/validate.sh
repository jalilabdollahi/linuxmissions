#!/bin/bash
# Only the young sessions remain in the hog directory, nothing else changed,
# vm.img untouched, report.txt names the hog directory.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
python3 - <<'PY'
import hashlib, json, os, sys
t = json.load(open(".lm-state/truth.json"))
hog = t["hog"]
if not os.path.isfile("var/lib/vm/vm.img"):
    print("❌ vm.img is gone; it was not yours to delete"); sys.exit(1)
st = os.stat("var/lib/vm/vm.img")
if st.st_size != t["img"]["size"] or st.st_mtime_ns != t["img"]["mtime"] or hashlib.sha256(open("var/lib/vm/vm.img", "rb").read(1 << 20)).hexdigest() != t["img"]["head"]:
    print("❌ vm.img was modified or replaced; it must stay as it was"); sys.exit(1)
if st.st_blocks * 512 > 10 * 1024 ** 2:
    print("❌ vm.img lost its sparseness (it was rewritten or copied)"); sys.exit(1)
for p in t["others"]:
    if not os.path.exists(p):
        print("❌ %s was deleted, but only old sessions may go" % p); sys.exit(1)
now = set(os.path.join(hog, f) for f in os.listdir(hog)) if os.path.isdir(hog) else set()
young = set(t["young"])
if young - now:
    print("❌ sessions younger than one day were deleted (%d of them); active users lose their login" % len(young - now)); sys.exit(1)
left = len(now - young)
if left:
    print("❌ %d session files older than one day are still in %s; the inodes are not free yet" % (left, hog)); sys.exit(1)
extra = [os.path.join(r, f) for r, _, fs in os.walk("var") for f in fs]
known = set(t["others"]) | young | {"var/lib/vm/vm.img"}
if set(extra) - known:
    print("❌ unexpected file %s appeared under var/" % sorted(set(extra) - known)[0]); sys.exit(1)
if not os.path.isfile("report.txt"):
    print("❌ report.txt does not exist"); sys.exit(1)
txt = open("report.txt", errors="replace").read().strip().replace("\r", "")
norm = txt.rstrip("/")
if norm.startswith("./"): norm = norm[2:]
cwd = os.getcwd()
if norm.startswith(cwd + "/"): norm = norm[len(cwd) + 1:]
if norm != hog:
    if os.path.isdir(norm) and norm.startswith("var"):
        print("❌ report.txt names %s, which is not the directory with the most files" % norm)
    else:
        print("❌ report.txt must hold just the relative path of the directory with the most files")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ the inode hog is cleaned by policy, vm.img and everything else untouched, report.txt is right"
