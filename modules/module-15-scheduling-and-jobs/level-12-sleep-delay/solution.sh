#!/bin/bash
cat > wait_ready.sh <<'SH'
#!/bin/bash
# Wait until the app answers ./probe. Usage: wait_ready.sh [TIMEOUT_SECONDS]
limit="${1:-30}"
SECONDS=0
until ./probe >/dev/null; do
  if [ "$SECONDS" -ge "$limit" ]; then
    echo "wait_ready: app not ready after ${limit}s" >&2
    exit 1
  fi
  sleep 2
done
echo "wait_ready: app ready after ${SECONDS}s"
SH
chmod +x wait_ready.sh
./wait_ready.sh 4; echo "exit $?"
