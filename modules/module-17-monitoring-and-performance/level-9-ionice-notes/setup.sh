#!/bin/bash
# A real `tar -czf` backup (tar + its gzip child) writing into a FIFO that a slow
# sink drains, so both stay alive for the whole session. tar/gzip are in their
# own process group (setsid); the database is a separate idle-loop process.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p srv/data backup opt/db opt/backup .lm-state

head -c 24M /dev/urandom > srv/data/orders.dump
echo "customers,orders,invoices" > srv/data/README.txt

cat > opt/db/dbserver.sh <<'LMEND'
#!/bin/bash
# database server (placeholder loop)
while :; do sleep 20; done
LMEND
cat > opt/backup/offsite-sink.sh <<'LMEND'
#!/bin/bash
# stand-in for a slow offsite link: reads 4 KiB every 30 seconds from the FIFO
exec 3< "$1"
while :; do dd bs=4096 count=1 <&3 >/dev/null 2>&1; sleep 30; done
LMEND

mkfifo backup/nightly.tgz
bash "$SANDBOX/opt/db/dbserver.sh" >/dev/null 2>&1 &
bash "$SANDBOX/opt/backup/offsite-sink.sh" "$SANDBOX/backup/nightly.tgz" >/dev/null 2>&1 &
setsid tar -czf "$SANDBOX/backup/nightly.tgz" -C "$SANDBOX/srv/data" . >/dev/null 2>&1 &

# GNU tar -z starts a helper (tar child -> sh -c gzip -> gzip): find the gzip below tar
descendants() { local p; for p in $(pgrep -P "$1"); do echo "$p"; descendants "$p"; done; }
TAR=""; GZ=""
for _ in $(seq 1 50); do
  TAR=$(pgrep -f "tar -czf $SANDBOX/backup/nightly.tgz" | head -1)
  GZ=""
  if [ -n "$TAR" ]; then
    for p in $(descendants "$TAR"); do
      [ "$(cat /proc/$p/comm 2>/dev/null)" = gzip ] && GZ=$p
    done
  fi
  [ -n "$TAR" ] && [ -n "$GZ" ] && break
  sleep 0.2
done
[ -n "$TAR" ] && [ -n "$GZ" ] || { echo "backup did not start" >&2; exit 1; }
DB=$(pgrep -f "$SANDBOX/opt/db/dbserver.sh" | head -1)
echo "tar $TAR" > .lm-state/pids
echo "gzip $GZ" >> .lm-state/pids
echo "db $DB" >> .lm-state/pids
ionice -p "$DB" > .lm-state/db.io
