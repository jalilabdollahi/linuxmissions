#!/bin/bash
# Wargame 16: twelve processes named "worker", one of them floods spool/.
# The runaway runs from a different copy of bash (different /proc/PID/exe) but
# is started with the same argv as the others, so ps cannot tell them apart.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf spool opt .lm culprit.txt
mkdir -p spool opt/app opt/vendor .lm

VDIR="opt/vendor/.$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
mkdir -p "$VDIR"
ln -s "$(command -v bash)" opt/app/worker
cp "$(command -v bash)" "$VDIR/worker"

cat > opt/app/worker.sh <<'SCRIPT'
#!/bin/bash
# $1 = worker id. Normal workers write a heartbeat line; "w07-style" ones burst
# a little more; one is CPU-chatty; one copy runs from the vendor directory.
id="$1"
out="$SPOOL/w$id.log"
exec 3>>"$out"
printf 'w%s up\n' "$id" >&3
case "$WORKER_KIND" in
  flood)
    chunk=$(head -c 262144 /dev/zero | tr '\0' 'x')
    n=0
    while [ "$n" -lt 240 ]; do
      [ $((n % 40)) -eq 0 ] && { exec 4>"$SPOOL/.dump-$(printf %04d $n).part"; }
      printf '%s' "$chunk" >&4
      n=$((n + 1)); sleep 0.05
    done
    while :; do sleep 2; done ;;
  burst)
    line=$(head -c 3000 /dev/zero | tr '\0' 'b')
    while :; do printf '%s %s\n' "$id" "$line" >&3; sleep 2; done ;;
  cpu)
    while :; do for i in 1 2 3 4 5 6; do :; done; sleep 0.01; done ;;
  *)
    while :; do printf 'w%s alive %s\n' "$id" "$SECONDS" >&3; sleep 2; done ;;
esac
SCRIPT

# ids 01..12 in random start order; one culprit, one burster, one cpu-chatty
ids=$(seq -w 1 12 | shuf)
culprit=$(seq -w 1 12 | shuf -n 1)
burst=$(seq -w 1 12 | grep -v "^$culprit$" | shuf -n 1)
cpu=$(seq -w 1 12 | grep -v "^$culprit$" | grep -v "^$burst$" | shuf -n 1)
: > .lm/legit.pids
for id in $ids; do
  kind=normal; [ "$id" = "$burst" ] && kind=burst; [ "$id" = "$cpu" ] && kind=cpu
  if [ "$id" = "$culprit" ]; then
    SPOOL="$SANDBOX/spool" WORKER_KIND=flood setsid bash -c 'exec -a "$1" "$2" "$3" "$4"' _ \
      "$SANDBOX/opt/app/worker" "$SANDBOX/$VDIR/worker" "$SANDBOX/opt/app/worker.sh" "$id" >/dev/null 2>&1 &
    echo "$! $(readlink -f "$SANDBOX/$VDIR/worker") $id" > .lm/culprit
  else
    SPOOL="$SANDBOX/spool" WORKER_KIND=$kind setsid "$SANDBOX/opt/app/worker" "$SANDBOX/opt/app/worker.sh" "$id" >/dev/null 2>&1 &
    echo "$! $id" >> .lm/legit.pids
  fi
  sleep 0.1
done
sleep 1
cat > NOTES.txt <<'TXT'
ingest-03: spool/ is on its own volume. Workers are started by opt/app/worker.
TXT
exit 0
