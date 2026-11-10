#!/bin/bash
# Three real holders of data/ (a writer with a file open, a reader with another
# file open, an indexer whose cwd is data/queue) and two decoys that only look
# related (data-old/ shares the prefix, log/ is a different directory).
# Python is used for the holders because a bash loop's `sleep` child would
# inherit the open fd / cwd and show up as extra holders.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SANDBOX=$(pwd -P)
mkdir -p opt data/queue data/archive data-old log .lm-state

echo "2026-11-09 job accepted" > data/queue/journal.log
head -c 200000 /dev/urandom > data/archive/2026-q3.dat
head -c 80000 /dev/urandom > data/archive/2026-q2.dat
echo "id,state" > data/queue/pending.csv
head -c 50000 /dev/urandom > data-old/2025.dat
echo "boot ok" > log/app.log

cat > opt/queue-writer.py <<'LMEND'
#!/usr/bin/env python3
# appends a heartbeat to data/queue/journal.log, keeping the file open
import os, sys, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
f = open(os.path.join(root, "data/queue/journal.log"), "a")
while True:
    f.write("tick\n"); f.flush(); time.sleep(5)
LMEND
cat > opt/archive-reader.py <<'LMEND'
#!/usr/bin/env python3
# keeps the Q3 archive open for reading
import os, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
f = open(os.path.join(root, "data/archive/2026-q3.dat"), "rb")
while True:
    f.seek(0); f.read(16); time.sleep(5)
LMEND
cat > opt/indexer.py <<'LMEND'
#!/usr/bin/env python3
# started from a shell that was sitting in data/queue; holds no file open
import os, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(root, "data/queue"))
while True:
    time.sleep(5)
LMEND
cat > opt/old-reader.py <<'LMEND'
#!/usr/bin/env python3
# reads the previous year's copy in data-old/ (a different directory)
import os, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
f = open(os.path.join(root, "data-old/2025.dat"), "rb")
while True:
    f.seek(0); f.read(16); time.sleep(5)
LMEND
cat > opt/log-tailer.py <<'LMEND'
#!/usr/bin/env python3
# works from log/ and keeps log/app.log open
import os, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(root, "log"))
f = open("app.log", "rb")
while True:
    f.seek(0); f.read(16); time.sleep(5)
LMEND

: > .lm-state/holders
for name in queue-writer archive-reader indexer old-reader log-tailer; do
  python3 "$SANDBOX/opt/$name.py" >/dev/null 2>&1 &
  echo "$name $!" >> .lm-state/pids
done
sleep 1
pid_of() { awk -v n="$1" '$1==n {print $2}' .lm-state/pids; }
for name in queue-writer archive-reader indexer old-reader log-tailer; do
  [ -d "/proc/$(pid_of $name)" ] || { echo "$name did not start" >&2; exit 1; }
done
echo "$(pid_of queue-writer) $SANDBOX/data/queue/journal.log" >> .lm-state/holders
echo "$(pid_of archive-reader) $SANDBOX/data/archive/2026-q3.dat" >> .lm-state/holders
echo "$(pid_of indexer) $SANDBOX/data/queue" >> .lm-state/holders
