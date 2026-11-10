#!/bin/bash
# Service Down: myapp.service will not start (ExecStart points at the old
# binary path) and cannot be enabled (no [Install] section). The sandbox acts
# as the filesystem root for the mock systemctl: /etc/... means ./etc/...
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p etc/systemd/system opt/myapp/releases/2.4.1/bin run/systemd/loaded

# New release layout: /opt/myapp/current -> releases/2.4.1
cat > opt/myapp/releases/2.4.1/bin/myapp <<'EOF'
#!/bin/bash
echo "myapp 2.4.1 listening on ${2:-8080}"
EOF
chmod +x opt/myapp/releases/2.4.1/bin/myapp
ln -s releases/2.4.1 opt/myapp/current

cat > etc/systemd/system/myapp.service <<'EOF'
[Unit]
Description=MyApp API server
After=network.target

[Service]
Type=simple
User=myapp
ExecStart=/opt/myapp/bin/myapp --port 8080
Restart=on-failure
EOF

# systemd has already loaded this (broken) version of the unit.
cp etc/systemd/system/myapp.service run/systemd/loaded/myapp.service
echo failed > run/systemd/myapp.service.state

cat > systemctl <<'SCRIPT'
#!/bin/bash
# Mock systemctl for LinuxMissions. Not the real systemd: it treats the
# sandbox as "/", reads units from ./etc/systemd/system and keeps runtime
# state in ./run/systemd. Supports: status, start, stop, restart, enable
# [--now], disable, is-enabled, is-active, daemon-reload, cat.
ROOT="$(cd "$(dirname "$0")" && pwd)"
UNIT_DIR="$ROOT/etc/systemd/system"
STATE="$ROOT/run/systemd"
mkdir -p "$STATE/loaded"

now=0
args=()
for a in "$@"; do
  case "$a" in
    --now) now=1 ;;
    --no-pager|-l|--full|-q|--quiet) ;;
    *) args+=("$a") ;;
  esac
done
cmd="${args[0]:-}"
unit="${args[1]:-}"

norm_unit() {
  case "$1" in
    "") echo "Too few arguments." >&2; exit 1 ;;
    *.service) echo "$1" ;;
    *) echo "$1.service" ;;
  esac
}

unit_file() { echo "$UNIT_DIR/$1"; }

need_unit() {
  if [ ! -f "$(unit_file "$1")" ]; then
    echo "Failed to $cmd $1: Unit $1 not found." >&2
    exit 5
  fi
}

# Print the values of Key= inside [Section] of a unit file.
unit_get() {
  awk -v sec="[$2]" -v key="$3" '
    /^[[:space:]]*[#;]/ { next }
    /^[[:space:]]*\[/ { gsub(/[[:space:]]/, ""); cur = $0; next }
    cur == sec {
      line = $0; sub(/^[[:space:]]+/, "", line)
      if (index(line, key "=") == 1) print substr(line, length(key) + 2)
    }' "$1"
}

changed_on_disk() {
  ! cmp -s "$(unit_file "$1")" "$STATE/loaded/$1"
}

warn_changed() {
  if changed_on_disk "$1"; then
    echo "Warning: The unit file, source configuration file or drop-ins of $1 changed on disk. Run 'systemctl daemon-reload' to reload units." >&2
  fi
}

reload_all() {
  for f in "$UNIT_DIR"/*.service; do
    [ -f "$f" ] && cp "$f" "$STATE/loaded/$(basename "$f")"
  done
}

enabled_state() {
  local u="$1" f wanted
  f="$(unit_file "$u")"
  wanted="$(unit_get "$f" Install WantedBy; unit_get "$f" Install RequiredBy)"
  if [ -z "$wanted" ]; then echo static; return; fi
  for d in "$UNIT_DIR"/*.wants "$UNIT_DIR"/*.requires; do
    [ -L "$d/$u" ] && { echo enabled; return; }
  done
  echo disabled
}

active_state() { cat "$STATE/$1.state" 2>/dev/null || echo inactive; }

do_start() {
  local u="$1" exec bin
  warn_changed "$u"
  exec="$(unit_get "$STATE/loaded/$u" Service ExecStart | tail -n 1)"
  exec="${exec#[-@+!]}"
  bin="${exec%% *}"
  echo "$exec" > "$STATE/$u.exec"
  case "$bin" in
    /*) ;;
    *) bin="" ;;
  esac
  if [ -z "$bin" ] || [ ! -f "$ROOT$bin" ] || [ ! -x "$ROOT$bin" ]; then
    echo failed > "$STATE/$u.state"
    echo "$u: Failed to locate executable ${exec%% *}: No such file or directory" > "$STATE/$u.journal"
    echo "Job for $u failed because the control process exited with error code." >&2
    echo "See \"systemctl status $u\" and \"journalctl -xeu $u\" for details." >&2
    exit 1
  fi
  echo active > "$STATE/$u.state"
  echo "Started $u - $(unit_get "$STATE/loaded/$u" Unit Description)." > "$STATE/$u.journal"
}

do_enable() {
  local u="$1" f wanted t
  reload_all   # real systemctl enable reloads the manager configuration
  f="$(unit_file "$u")"
  wanted="$(unit_get "$f" Install WantedBy)"
  if [ -z "$wanted" ]; then
    cat >&2 <<EOF
The unit files have no installation config (WantedBy=, RequiredBy=, UpheldBy=,
Also=, or Alias= settings in the [Install] section, and DefaultInstance= for
template units). This means they are not meant to be enabled or disabled using systemctl.
EOF
    return 0
  fi
  for t in $wanted; do
    if [ ! -L "$UNIT_DIR/$t.wants/$u" ]; then
      mkdir -p "$UNIT_DIR/$t.wants"
      ln -s "../$u" "$UNIT_DIR/$t.wants/$u"
      echo "Created symlink /etc/systemd/system/$t.wants/$u → /etc/systemd/system/$u."
    fi
  done
}

case "$cmd" in
  daemon-reload)
    reload_all ;;
  start|restart)
    u="$(norm_unit "$unit")"; need_unit "$u"; do_start "$u" ;;
  stop)
    u="$(norm_unit "$unit")"; need_unit "$u"; echo inactive > "$STATE/$u.state" ;;
  enable)
    u="$(norm_unit "$unit")"; need_unit "$u"; do_enable "$u"
    if [ "$now" = 1 ]; then do_start "$u"; fi ;;
  disable)
    u="$(norm_unit "$unit")"; need_unit "$u"
    for l in "$UNIT_DIR"/*.wants/"$u"; do
      [ -L "$l" ] && rm -f "$l" && echo "Removed \"/etc/systemd/system/$(basename "$(dirname "$l")")/$u\"."
    done ;;
  is-enabled)
    u="$(norm_unit "$unit")"; need_unit "$u"; s="$(enabled_state "$u")"; echo "$s"
    [ "$s" = enabled ] ;;
  is-active)
    u="$(norm_unit "$unit")"; s="$(active_state "$u")"; echo "$s"
    [ "$s" = active ] ;;
  cat)
    u="$(norm_unit "$unit")"; need_unit "$u"
    echo "# /etc/systemd/system/$u"; cat "$(unit_file "$u")" ;;
  status)
    u="$(norm_unit "$unit")"; need_unit "$u"
    s="$(active_state "$u")"
    case "$s" in
      active) shown="active (running)" ;;
      failed) shown="failed (Result: exit-code)" ;;
      *) shown="inactive (dead)" ;;
    esac
    echo "● $u - $(unit_get "$STATE/loaded/$u" Unit Description)"
    echo "     Loaded: loaded (/etc/systemd/system/$u; $(enabled_state "$u"); preset: enabled)"
    echo "     Active: $shown"
    if [ "$s" = failed ]; then
      echo "    Process: 4242 ExecStart=$(unit_get "$STATE/loaded/$u" Service ExecStart | tail -n 1) (code=exited, status=203/EXEC)"
    fi
    if [ -f "$STATE/$u.journal" ]; then
      echo
      sed 's/^/Apr 08 14:30:00 web01 systemd[1]: /' "$STATE/$u.journal"
    fi
    warn_changed "$u"
    [ "$s" = active ] || exit 3 ;;
  *)
    echo "usage: ./systemctl {status|start|stop|restart|enable [--now]|disable|is-enabled|is-active|daemon-reload|cat} <unit>" >&2
    exit 1 ;;
esac
SCRIPT
chmod +x systemctl

# The first start attempt already failed before the player arrived.
echo "myapp.service: Failed to locate executable /opt/myapp/bin/myapp: No such file or directory" > run/systemd/myapp.service.journal
