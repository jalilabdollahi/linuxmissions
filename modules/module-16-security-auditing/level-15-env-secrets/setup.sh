#!/bin/bash
# Two background workers run in the sandbox. One was started with --password=PW on its
# command line (visible to every user in ps); the other only has PASSWORD_FILE=<path>
# in its environment, which is harmless. Which names are used and which worker leaks is
# random. app/worker.sh is a stand-in for the real worker: it reads its database password
# from --password=, or else from the file named by $PASSWORD_FILE, checks it against
# .lm-state/passwords, logs "connected"/"authentication failed", then idles.
# Both workers carry "$SANDBOX/app/worker.sh" in their command line, so the engine
# stops them on reset.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
pkill -f "$SANDBOX/app/worker.sh" 2>/dev/null; sleep 0.2
rm -rf app secrets logs leak.txt .lm-state; mkdir -p app secrets logs .lm-state

pairs=("billing reports" "ledger mailer" "exporter notifier")
read -r leaker quiet <<< "${pairs[RANDOM % 3]}"
if [ $((RANDOM % 2)) -eq 0 ]; then t=$leaker; leaker=$quiet; quiet=$t; fi
mkpw() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 14; }
pw_leak="Db-$(mkpw)"; pw_quiet="Rp-$(mkpw)"
printf '%s=%s\n%s=%s\n' "$leaker" "$pw_leak" "$quiet" "$pw_quiet" > .lm-state/passwords
printf '%s\n' "$pw_quiet" > secrets/quiet.pass; chmod 600 secrets/quiet.pass
chmod 755 secrets

cat > app/worker.sh <<'WORKER'
#!/bin/bash
# worker.sh NAME [--password=PW]   (or set PASSWORD_FILE=path)
name=$1; shift
root=$(cd "$(dirname "$0")/.." && pwd)
pw=
for a in "$@"; do case $a in --password=*) pw=${a#--password=} ;; esac; done
if [ -z "$pw" ] && [ -n "$PASSWORD_FILE" ]; then pw=$(cat "$PASSWORD_FILE" 2>/dev/null); fi
stamp() { date +%H:%M:%S; }
if grep -qxF "$name=$pw" "$root/.lm-state/passwords"; then
  echo "$(stamp) [pid $$] $name: connected to db" >> "$root/logs/$name.log"
else
  echo "$(stamp) [pid $$] $name: authentication failed (no or wrong password)" >> "$root/logs/$name.log"
  exit 1
fi
while :; do sleep 30; done
WORKER

cat > app/start-worker.sh <<EOF2
#!/bin/bash
# Starts the $leaker worker (called by the nightly deploy).
cd "\$(dirname "\$0")/.." || exit 1
DB_PASSWORD='$pw_leak'
nohup bash "\$PWD/app/worker.sh" $leaker --password="\$DB_PASSWORD" >/dev/null 2>&1 &
EOF2
chmod 755 app/start-worker.sh app/worker.sh

# start both
nohup bash "$SANDBOX/app/worker.sh" "$leaker" --password="$pw_leak" >/dev/null 2>&1 &
echo $! > .lm-state/leaker.pid
PASSWORD_FILE="$SANDBOX/secrets/quiet.pass" nohup bash "$SANDBOX/app/worker.sh" "$quiet" >/dev/null 2>&1 &
echo $! > .lm-state/quiet.pid
echo "$leaker" > .lm-state/leaker.name
echo "$quiet" > .lm-state/quiet.name
echo "$pw_leak" > .lm-state/leaker.pw
for _ in $(seq 20); do
  [ -s "logs/$leaker.log" ] && [ -s "logs/$quiet.log" ] && break
  sleep 0.1
done
exit 0
