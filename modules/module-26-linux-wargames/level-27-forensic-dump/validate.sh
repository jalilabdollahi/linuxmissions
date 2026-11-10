#!/bin/bash
SB="$1"; cd "$SB" || exit 1
if [ ! -s incident.json ]; then echo "❌ incident.json is missing or empty"; exit 1; fi
if ! jq -e . incident.json >/dev/null 2>&1; then echo "❌ incident.json is not valid JSON"; exit 1; fi
if [ "$(jq -S 'keys' incident.json | tr -d ' \n')" != '["dropped_binary","exfil_host","first_malicious_login","persistence"]' ]; then echo "❌ incident.json must have exactly the keys first_malicious_login, persistence, exfil_host, dropped_binary"; exit 1; fi
chk() {  # label jq-filter
  a=$(jq -cS "$2" incident.json 2>/dev/null); b=$(jq -cS "$2" .lm/expected.json)
  if [ "$a" != "$b" ]; then echo "❌ $1 is wrong"; exit 1; fi
}
chk "first_malicious_login.ip (who got in first from outside?)" '.first_malicious_login.ip'
chk "first_malicious_login.time_utc (check the server's time zone and the format)" '.first_malicious_login.time_utc'
chk "dropped_binary (timestamps can be faked, some can not)" '.dropped_binary'
chk "exfil_host (the host name only, as the binary carries it)" '.exfil_host'
chk "persistence (the files that define it, sorted, absolute host paths)" '.persistence'
echo "✅ incident.json matches the evidence"
