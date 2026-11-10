#!/bin/bash
# public/ holds exactly the verified files (the in-flight one only in its
# final form), rejected.txt lists exactly the corrupt/truncated/missing ones.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
busy=0
if ! flock -n mirror/upload.lock true 2>/dev/null; then busy=1; fi
python3 - "$busy" <<'PY'
import hashlib, json, os, sys
busy = sys.argv[1] == "1"
t = json.load(open(".lm-state/truth.json"))
if not os.path.isdir("public"):
    print("❌ public/ does not exist"); sys.exit(1)
have = sorted(f for f in os.listdir("public"))
good = t["good"]; infl = t["inflight"]
for f in have:
    if f not in good:
        print("❌ public/%s must not be there: it does not verify against SHA256SUMS" % f); sys.exit(1)
for f in have:
    h = hashlib.sha256(open("public/" + f, "rb").read()).hexdigest()
    if h != t["sums"][f]:
        if f == infl:
            print("❌ public/%s is truncated: it was copied while the upload was still running" % f)
        else:
            print("❌ public/%s does not match its checksum" % f)
        sys.exit(1)
missing = [f for f in good if f not in have]
if missing:
    if infl in missing and busy:
        print("❌ the last file is not published and the uploader still holds upload.lock: publish it after the upload has finished")
    elif infl in missing and len(missing) == 1:
        print("❌ the in-flight file %s is not in public/ although its upload has finished" % infl)
    else:
        print("❌ public/ is missing %d verified file(s), for example %s" % (len(missing), missing[0]))
    sys.exit(1)
if not os.path.isfile("rejected.txt"):
    print("❌ rejected.txt does not exist"); sys.exit(1)
rej = sorted(set(l.replace("\r", "").strip() for l in open("rejected.txt", errors="replace") if l.strip()))
exp = t["rejected"]
if rej != exp:
    if infl in rej:
        print("❌ rejected.txt lists %s, which only looked bad because its upload was not finished" % infl)
    elif [r for r in rej if r not in exp]:
        print("❌ rejected.txt lists %s, which is fine" % [r for r in rej if r not in exp][0])
    else:
        print("❌ rejected.txt misses %d listed file(s) that are corrupt, truncated or missing" % (len(exp) - len(rej)))
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ public/ has exactly the verified files (the big one complete) and rejected.txt is exact"
