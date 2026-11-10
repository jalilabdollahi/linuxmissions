#!/bin/bash
# Drain Then Switch: an upload queue that drains at its own pace once the
# uploader is resumed. The last entries to go are hidden in-flight files
# (.upload-*.part), so `ls spool | wc -l` reaches 0 a few seconds too early.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p spool .lm

for i in $(seq 1 22); do
  n=$(printf '%04d' $((3100 + i)))
  printf '{"order": %s, "region": "eu-west-1", "bytes": %d}\n' "$n" $((RANDOM * 37)) > "spool/upload-$n.json"
done
for i in 23 24 25; do
  n=$(printf '%04d' $((3100 + i)))
  head -c $((2000 + RANDOM % 900)) /dev/zero | tr '\0' 'x' > "spool/.upload-$n.json.part"
done

# The uploader daemon: ships visible files one by one, then waits for the
# in-flight (hidden) uploads to finish. Writes the exact moment the queue is
# empty to .lm/drained-at (epoch seconds with nanoseconds).
cat > .lm/uploader <<'EOF'
#!/bin/bash
cd "$1" || exit 1
echo $$ > .lm/uploader.pid
log() { echo "$(date '+%H:%M:%S') $*" >> uploader.log; }
log "uploader resumed, $(ls -A spool | wc -l) entries queued"
sleep $((RANDOM % 4 + 3))
for f in spool/upload-*.json; do
  [ -e "$f" ] || continue
  sleep "0.$((RANDOM % 7 + 3))"
  sleep $((RANDOM % 2))
  rm -f "$f" && log "uploaded ${f#spool/}"
done
for f in spool/.upload-*.part; do
  [ -e "$f" ] || continue
  sleep "$((RANDOM % 2 + 2)).$((RANDOM % 10))"
  rm -f "$f" && log "finished in-flight ${f#spool/.}"
done
date +%s.%N > .lm/drained-at
log "queue empty"
rm -f .lm/uploader.pid
EOF

cat > resume-uploads.sh <<'EOF'
#!/bin/bash
# Resume the paused uploader. It drains spool/ in the background at its own
# pace; progress goes to uploader.log.
cd "$(dirname "$0")" || exit 1
here=$(pwd)
if [ -f .lm/uploader.pid ] && kill -0 "$(cat .lm/uploader.pid)" 2>/dev/null; then
  echo "uploader is already running (see uploader.log)"
  exit 0
fi
if [ -z "$(ls -A spool)" ]; then
  echo "nothing to upload: spool/ is empty"
  exit 0
fi
nohup bash "$here/.lm/uploader" "$here" >/dev/null 2>&1 </dev/null &
echo "uploader resumed: $(ls -A spool | wc -l) entries in spool/"
EOF
chmod +x resume-uploads.sh

cat > switch-traffic.sh <<'EOF'
#!/bin/bash
# Point the load balancer at eu-west-2. Only safe once every upload has left
# spool/: anything still queued here is lost when eu-west-1 is drained.
cd "$(dirname "$0")" || exit 1
left=$(ls -A spool | wc -l)
echo "$(date +%s.%N) $left" >> .lm/switch-at
echo "$(date '+%H:%M:%S') traffic switched to eu-west-2 ($left entries were still in spool/)" >> traffic.log
echo "traffic switched to eu-west-2"
EOF
chmod +x switch-traffic.sh

cat > CHANGE.txt <<'EOF'
CHANGE-8812  move upload traffic from eu-west-1 to eu-west-2

1. Resume the uploader:   ./resume-uploads.sh
   It drains spool/ in the background, somewhere within the next minute.
   Files still being uploaded sit in spool/ until they are finished.
2. As soon as spool/ is empty, switch:   ./switch-traffic.sh
   Too early and the queued uploads are lost. Too late and the clients time
   out (the load balancer gives us 5 seconds).
EOF
