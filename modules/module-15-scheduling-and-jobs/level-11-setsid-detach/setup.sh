#!/bin/bash
# Cut the Cord: run consumer.sh in its own session, without a controlling
# terminal, stdin from /dev/null, output appended to logs/consumer.log.
# consumer.sh re-executes itself by its absolute path so the sandbox path is
# in its command line (the engine stops it on reset).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p queue done logs

cat > consumer.sh <<'SH'
#!/bin/bash
# Order-queue consumer: moves every message from queue/ to done/, forever.
case "$0" in
  /*) ;;
  *) exec "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$@" ;;
esac
HERE="$(dirname "$0")"
echo "$(date '+%F %T') consumer started (pid $$)"
[ -t 0 ] && echo "$(date '+%F %T') warning: stdin is a terminal; I might steal your keystrokes" >&2
while true; do
  for msg in "$HERE"/queue/*.msg; do
    [ -e "$msg" ] || continue
    if mv "$msg" "$HERE/done/"; then
      echo "$(date '+%F %T') processed ${msg##*/}"
    fi
  done
  sleep 1
done
SH
chmod 755 consumer.sh

for n in 7781 7782 7783 7784; do
  printf 'order=%s\nitems=%s\n' "$n" "$((n % 5 + 1))" > "queue/order-$n.msg"
done

cat > logs/consumer.log <<'LOG'
2025-11-04 09:12:40 consumer started (pid 2210)
2025-11-04 09:12:41 processed order-7702.msg
2025-11-04 17:48:03 processed order-7765.msg
(consumer gone after the SSH session to app-01 dropped)
LOG
