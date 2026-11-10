#!/bin/bash
# Mirror sync "with warnings": SHA256SUMS has CRLF endings and `*` binary
# markers; one file has the right size but other content, one is truncated,
# one is missing; the uploader (background, holds flock on upload.lock)
# is still writing the last file straight into mirror/data/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p mirror/data .lm-state bin
cat > bin/uploader.py <<'PY'
#!/usr/bin/env python3
# The mirror's uploader: holds an exclusive flock on upload.lock while it
# writes the last file chunk by chunk into the data directory.
import fcntl, os, sys, time
src, dst, lock, secs = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
data = open(src, "rb").read()
lk = open(lock, "w")
fcntl.flock(lk, fcntl.LOCK_EX)
chunks = 40
step = -(-len(data) // chunks)
with open(dst, "wb") as f:
    for i in range(chunks):
        f.write(data[i * step:(i + 1) * step]); f.flush()
        time.sleep(secs / chunks)
fcntl.flock(lk, fcntl.LOCK_UN)
PY
python3 - <<'PY'
import hashlib, json, os, random
R = random.Random()
names = ["libfoo-%d.%d.tar.gz" % (R.randint(1, 4), R.randint(0, 9)), "release-notes.pdf", "bar-installer.run", "data-2026-11.csv.xz", "docs bundle.zip", "keyring.gpg", "tools-linux-amd64.tgz", "firmware-%d.bin" % R.randint(10, 99), "extras.tar"]
names = list(dict.fromkeys(names))
blobs = {n: R.randbytes(R.randint(20000, 60000)) for n in names}
inflight = "images-%s.iso" % R.choice(["2026.11", "stable", "nightly"])
final = R.randbytes(R.randint(180000, 260000))
sums = {n: hashlib.sha256(b).hexdigest() for n, b in blobs.items()}
sums[inflight] = hashlib.sha256(final).hexdigest()
bad = R.sample(names, 3)
corrupt, trunc, missing = bad
for n, b in blobs.items():
    if n == missing: continue
    if n == corrupt:
        i = R.randint(100, len(b) - 100); b = b[:i] + bytes([b[i] ^ 0x5A]) + b[i + 1:]
    if n == trunc:
        b = b[: len(b) * 2 // 3]
    open("mirror/data/" + n, "wb").write(b)
open(".lm-state/inflight.src", "wb").write(final)
order = list(sums); R.shuffle(order)
with open("mirror/SHA256SUMS", "w", newline="") as f:
    for i, n in enumerate(order):
        f.write("%s %s%s\r\n" % (sums[n], "*" if i % 2 == 0 else " ", n))
good = sorted(n for n in names if n not in bad) + [inflight]
json.dump({"good": good, "rejected": sorted(bad), "inflight": inflight, "sums": sums}, open(".lm-state/truth.json", "w"))
open("README-MIRROR.md", "w").write("""# Mirror sync ended "with warnings"

`mirror/data/` is what the sync pulled, `mirror/SHA256SUMS` is what the
upstream says every file should hash to (written on another OS).

Publish into `public/` only files that verify against it. List the rest of
the listed files (corrupt, truncated or missing) in `rejected.txt`, one name
per line. One big file is still being uploaded by `bin/uploader.py`: it holds
a lock on `mirror/upload.lock` while it writes. Do not publish half a file.
Files that are not listed in SHA256SUMS do not exist as far as we are concerned.
""")
open(".lm-state/secs", "w").write(str(R.randint(16, 22)))
PY
python3 -c "print(open('.lm-state/secs').read().strip())" > /dev/null
touch mirror/upload.lock
python3 "$SANDBOX/bin/uploader.py" .lm-state/inflight.src "mirror/data/$(python3 -c "import json;print(json.load(open('.lm-state/truth.json'))['inflight'])")" "$SANDBOX/mirror/upload.lock" "$(cat .lm-state/secs)" >/dev/null 2>&1 < /dev/null &
sleep 1
