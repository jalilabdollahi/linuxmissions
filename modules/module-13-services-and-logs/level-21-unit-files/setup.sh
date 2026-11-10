#!/bin/bash
# Unit file from scratch: report-api is started by hand in tmux
# (notes/tmux-history.txt). The script reads ./report-api.conf (needs its
# install dir as cwd, else exit 78) and, without --foreground, daemonizes
# itself with `nohup ... &` and exits 0: under Type=simple systemd sees the
# main process exit and stops the unit (control-group kill). It writes
# var/run/report-api/health (pid=, port=, cwd=) every half second. The port
# is random per setup (TICKET.md). A stale health file from the old
# hand-started run is left behind. Mock systemctl/journalctl/systemd-analyze
# in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state notes etc/systemd/system/multi-user.target.wants opt/report-api/bin var/run/report-api var/log/journal
cp "$M/systemd/systemctl" "$M/systemd/journalctl" "$M/systemd/systemd-analyze" bin/
echo rpt-01 > etc/hostname
echo "2026-11-10 09:05:00" > .lm/now

ports=(8089 8443 9100 7070)
PORT=${ports[$((RANDOM % 4))]}
echo "$PORT" > .lm-state/port

cat > opt/report-api/bin/report-api <<'LMEND2'
#!/bin/bash
# report-api: HTTP API for the monthly reports (stand-in).
#   report-api --port N [--foreground]
# Reads ./report-api.conf from the current directory. Without --foreground it
# detaches into the background and the launching process exits.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PORT=""; FG=0
while [ $# -gt 0 ]; do
  case $1 in
    --port) PORT=$2; shift 2 ;;
    --foreground) FG=1; shift ;;
    *) echo "report-api: unknown option $1" >&2; exit 64 ;;
  esac
done
[ -n "$PORT" ] || { echo "report-api: --port is required" >&2; exit 64; }
if [ ! -r ./report-api.conf ]; then
  echo "report-api: cannot read ./report-api.conf (run it from its install directory)" >&2
  exit 78
fi
if [ "$FG" = 0 ]; then
  nohup "$0" --foreground --port "$PORT" >/dev/null 2>&1 &
  echo "report-api: detached to the background (pid $!)"
  exit 0
fi
echo "report-api: listening on port $PORT, config $(pwd)/report-api.conf"
while :; do
  echo "pid=$$ port=$PORT cwd=$PWD" > "$ROOT/var/run/report-api/health"
  sleep 0.5
done
LMEND2
chmod +x opt/report-api/bin/report-api
cat > opt/report-api/report-api.conf <<'LMEND2'
# report-api configuration
report_dir = /srv/reports
max_rows = 500000
LMEND2

echo "pid=31337 port=$PORT cwd=/opt/report-api" > var/run/report-api/health

cat > notes/tmux-history.txt <<LMEND2
# from the tmux pane "reports" (session of ops-karim), last lines
karim@rpt-01:~$ cd /opt/report-api
karim@rpt-01:/opt/report-api$ ./bin/report-api --port $PORT &
[1] 31337
report-api: detached to the background (pid 31350)
karim@rpt-01:/opt/report-api$ ./bin/report-api --help
usage: report-api --port N [--foreground]
         --foreground   stay in the foreground (do not detach); for process supervisors
karim@rpt-01:/opt/report-api$ # TODO: make this a real service, tmux died twice already
LMEND2

cat > TICKET.md <<LMEND2
# OPS-3318: run report-api as a real service

report-api lives in a tmux pane and dies whenever the pane does. Write the
unit file for it (see notes/tmux-history.txt for how it is started today):

- file:        /etc/systemd/system/report-api.service
- runs:        /opt/report-api/bin/report-api on port $PORT
- it must start at boot (enabled for multi-user.target)
- restart it when it fails
- the file must pass systemd-analyze verify
- run it now under systemd (the hand-started copy is gone)

Do not change /opt/report-api.
LMEND2
bin/systemctl daemon-reload
