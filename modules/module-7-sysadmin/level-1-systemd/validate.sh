#!/bin/bash
SANDBOX="$1"
UNIT="$SANDBOX/etc/systemd/system/myapp.service"
BINARY="$SANDBOX/opt/myapp/releases/2.4.1/bin/myapp"

if [ ! -f "$UNIT" ]; then
  echo "❌ etc/systemd/system/myapp.service is missing"
  exit 1
fi

# Values of Key= inside [Section], comments ignored.
unit_get() {
  awk -v sec="[$1]" -v key="$2" '
    /^[[:space:]]*[#;]/ { next }
    /^[[:space:]]*\[/ { gsub(/[[:space:]]/, ""); cur = $0; next }
    cur == sec {
      line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
      if (index(line, key "=") == 1) print substr(line, length(key) + 2)
    }' "$UNIT"
}

# Does an ExecStart command line run the installed myapp binary with --port 8080?
exec_ok() {
  local line="${1#[-@+!]}" bin
  bin="${line%% *}"
  case "$bin" in /*) ;; *) return 1 ;; esac
  [ -x "$SANDBOX$bin" ] && [ "$SANDBOX$bin" -ef "$BINARY" ] || return 1
  printf '%s\n' " ${line#"$bin"} " | grep -Eq '[[:space:]]--port(=|[[:space:]]+)8080[[:space:]]'
}

EXEC="$(unit_get Service ExecStart | tail -n 1)"
if ! exec_ok "$EXEC"; then
  echo "❌ ExecStart in myapp.service does not point at an existing myapp binary (with --port 8080)"
  exit 1
fi

if ! unit_get Install WantedBy | tr ' ' '\n' | grep -qx 'multi-user.target'; then
  echo "❌ myapp.service has no [Install] section that hooks it into multi-user.target"
  exit 1
fi

LINK="$SANDBOX/etc/systemd/system/multi-user.target.wants/myapp.service"
if [ ! -L "$LINK" ] || [ ! "$LINK" -ef "$UNIT" ]; then
  echo "❌ myapp.service is not enabled (no multi-user.target.wants symlink)"
  exit 1
fi

if [ "$(cat "$SANDBOX/run/systemd/myapp.service.state" 2>/dev/null)" != "active" ]; then
  echo "❌ myapp.service is not running (check its status)"
  exit 1
fi

if ! exec_ok "$(cat "$SANDBOX/run/systemd/myapp.service.exec" 2>/dev/null)"; then
  echo "❌ myapp.service is running an old ExecStart; reload the unit files and restart it"
  exit 1
fi

echo "✅ myapp.service is fixed, enabled at boot and running"
exit 0
