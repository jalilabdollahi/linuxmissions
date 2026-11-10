#!/bin/bash
# Runs inspect.sh twice (no listeners / two listeners started here, 6 s apart), checks the JSON
# structure and types with jq -e and each value against its own reading of the machine.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
fail() { echo "❌ $*"; exit 1; }
[ -s inspect.sh ] || fail "inspect.sh does not exist yet"
[ "$(grep -vcE '^[[:space:]]*(#|$)' inspect.sh)" -gt 0 ] || fail "inspect.sh has no commands yet"
# nothing typed in: the identifying values must not appear as literals
for lit in "$(uname -n)" "$(uname -r)" "$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"; do
  [ "${#lit}" -ge 4 ] && grep -v '^[[:space:]]*#' inspect.sh | grep -qF -- "$lit" && fail "inspect.sh contains the literal '$lit': read it from the machine instead of typing it in"
done
LP=()
cleanup() { for p in "${LP[@]}"; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT
os() { ( . /etc/os-release 2>/dev/null; eval "echo \"\$$1\"" ); }
ports_own() { ss -ltnpH 2>/dev/null | awk '/users:/ {n = split($4, a, ":"); print a[n]}' | sort -un | jq -Rnc '[inputs | tonumber]'; }
ports_all() { ss -ltnH 2>/dev/null | awk '{n = split($4, a, ":"); print a[n]}' | sort -un | jq -Rnc '[inputs | tonumber]'; }
check() {   # $1 = label
  local lbl=$1 out err rc
  err=.lm-state/err
  out=$(timeout 10 bash ./inspect.sh 2>"$err" < /dev/null); rc=$?
  [ "$rc" -eq 0 ] || fail "inspect.sh exits with status $rc ($lbl): $(head -c 100 "$err" | tr '\n' ' ')"
  [ -n "$out" ] || fail "inspect.sh printed nothing on stdout ($lbl)"
  jq -e . <<< "$out" >/dev/null 2>&1 || fail "the output is not valid JSON ($lbl)"
  [ "$(jq -s 'length' <<< "$out")" = 1 ] || fail "print exactly one JSON object ($lbl)"
  jq -e 'type == "object"' <<< "$out" >/dev/null || fail "the JSON must be an object ($lbl)"
  want='["arch","cpus","hostname","kernel","listening_ports","mem_total_mib","os_id","os_version","root_use_pct","uptime_seconds"]'
  [ "$(jq -c 'keys' <<< "$out")" = "$want" ] || fail "the object must have exactly the ten keys of the ticket (missing, extra or misspelled: $(jq -c 'keys' <<< "$out"))"
  local k v
  for k in hostname kernel arch os_id os_version; do
    jq -e --arg k "$k" '.[$k] | type == "string"' <<< "$out" >/dev/null || fail "$k must be a JSON string"
  done
  for k in cpus mem_total_mib root_use_pct uptime_seconds; do
    jq -e --arg k "$k" '.[$k] | type == "number"' <<< "$out" >/dev/null || fail "$k must be a JSON number, not a string or anything else"
  done
  jq -e '.listening_ports | type == "array" and all(type == "number")' <<< "$out" >/dev/null \
    || fail "listening_ports must be an array of numbers ($lbl: got $(jq -c '.listening_ports' <<< "$out"))"
  [ "$(jq -r .hostname <<< "$out")" = "$(uname -n)" ] || fail "hostname is not the kernel's host name"
  [ "$(jq -r .kernel <<< "$out")" = "$(uname -r)" ] || fail "kernel is not the kernel release"
  [ "$(jq -r .arch <<< "$out")" = "$(uname -m)" ] || fail "arch is not the machine hardware name"
  [ "$(jq -r .os_id <<< "$out")" = "$(os ID)" ] || fail "os_id does not match ID in /etc/os-release (quotes?)"
  [ "$(jq -r .os_version <<< "$out")" = "$(os VERSION_ID)" ] || fail "os_version does not match VERSION_ID in /etc/os-release (quotes?)"
  jq -e --argjson a "$(nproc)" --argjson b "$(grep -c '^processor' /proc/cpuinfo)" '.cpus | . == $a or . == $b' <<< "$out" >/dev/null || fail "cpus is not the number of CPUs"
  local mem; mem=$(awk '/^MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
  jq -e --argjson m "$mem" '.mem_total_mib | (. - $m) | (. >= -1 and . <= 1)' <<< "$out" >/dev/null || fail "mem_total_mib is not MemTotal in MiB (MemTotal in /proc/meminfo is in kB)"
  local pct; pct=$(df -P / | awk 'NR == 2 {sub("%", "", $5); print $5}')
  jq -e --argjson p "$pct" '.root_use_pct | (. - $p) | (. >= -1 and . <= 1)' <<< "$out" >/dev/null || fail "root_use_pct is not the use percentage of / from df -P"
  local up; up=$(awk '{print $1}' /proc/uptime)
  jq -e --argjson u "$up" '.uptime_seconds | (. - $u) | (. >= -5 and . <= 5)' <<< "$out" >/dev/null || fail "uptime_seconds is not the seconds since boot ($lbl)"
  jq -e '.uptime_seconds == (.uptime_seconds | floor)' <<< "$out" >/dev/null || fail "uptime_seconds must be an integer"
  local got; got=$(jq -c '.listening_ports' <<< "$out")
  if [ "$got" != "$(ports_own)" ] && [ "$got" != "$(ports_all)" ]; then
    fail "listening_ports is $got but the listeners are $(ports_own) ($lbl); ascending, numeric, each port once"
  fi
}
check "no listener started"
sleep 6   # a hard-coded uptime would be off by now
start_listener() {   # $1 = address, $2 = port range
  local port
  for _ in 1 2 3 4 5 6; do
    port=$(shuf -i "$2" -n 1)
    python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((sys.argv[2], int(sys.argv[3]))); s.listen(4)
time.sleep(60)' "$SANDBOX" "$1" "$port" >/dev/null 2>&1 &
    local pid=$!
    sleep 0.4
    if kill -0 "$pid" 2>/dev/null; then LP+=("$pid"); return 0; fi
  done
  fail "could not start a test listener (try again)"
}
start_listener 0.0.0.0 10000-19999
start_listener 127.0.0.1 9000-9999
check "two listeners started"
cleanup
echo "✅ inspect.sh reports a correct, well-typed JSON document (also with listeners present)"
exit 0
