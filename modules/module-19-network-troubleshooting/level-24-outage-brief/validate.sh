#!/bin/bash
# $1 = sandbox path
# Checks each fix on its own, in the order the player runs into them, then
# runs the original smoke test and checks brief.md against the evidence.
#   proxy:   corp hosts go direct, the vendor still through the proxy
#   port:    PAYMENTS_PORT = the SRV port
#   backends: the 503 backend removed, the two healthy ones kept
#   hosts:   the moved backend resolves to its DNS address, other pins kept
SANDBOX="$1"
cd "$SANDBOX" || exit 1
read -r sick moved newport < .net/faults
proxy=$(cat .net/proxy.port)
tok="chk$RANDOM$RANDOM"

[ -f checkout/client.env ] || { echo "❌ checkout/client.env is missing"; exit 1; }
load() { env -i PATH="$PATH" HOME="$HOME" bash -c '. checkout/client.env >/dev/null 2>&1; '"$1"; }
seen() { for _ in 1 2 3 4 5 6 7 8 9 10; do grep -qF "$2" "$1" 2>/dev/null && return 0; sleep 0.2; done; return 1; }

# 1. proxy
load 'curl -s -o /dev/null --max-time 4 "$FX_URL'"?$tok"'"'
if ! seen .net/proxy.log "$tok"; then
  echo "❌ the FX rates (fx.vendor.example) must still go through the proxy; keep http_proxy"; exit 1
fi
load "curl -s -o /dev/null --max-time 3 --resolve pay-1.corp.example:$newport:127.0.20.11 http://pay-1.corp.example:$newport/$tok-direct"
if seen .net/proxy.log "$tok-direct"; then
  echo "❌ calls to *.corp.example still go through the proxy, which can't reach them (look at no_proxy)"; exit 1
fi

# 2. port
port=$(load 'printf %s "$PAYMENTS_PORT"')
if [ "$port" != "$newport" ]; then
  echo "❌ PAYMENTS_PORT=$port: nothing listens there any more; where did payments move to? (changes.log, DNS)"; exit 1
fi

# 3. backends
backends=$(load 'printf "%s\n" $PAYMENTS_BACKENDS' | sed 's/\.corp\.example$//' | sort | tr '\n' ' ')
want=$(printf 'pay-%s\n' 1 2 3 | grep -vx "pay-$sick" | sort | tr '\n' ' ')
if [ "$backends" != "$want" ]; then
  if echo " $backends" | grep -q " pay-$sick "; then
    echo "❌ one backend in PAYMENTS_BACKENDS accepts connections but answers every request with an error; take it out"
  else
    echo "❌ PAYMENTS_BACKENDS should keep the healthy backends (full names, as before)"
  fi
  exit 1
fi
if load 'printf "%s\n" $PAYMENTS_BACKENDS' | grep -qv '\.corp\.example$'; then
  echo "❌ PAYMENTS_BACKENDS: keep the full names (pay-N.corp.example)"; exit 1
fi

# 4. hosts
ask() { python3 "$1/bin/getent" hosts "$2" 2>/dev/null | awk '{ print $1 }'; }
tmp=$(mktemp -d)
mkdir -p "$tmp/bin" "$tmp/etc" "$tmp/.net"
cp .net/getent.orig "$tmp/bin/getent"; cp .net/dns.port "$tmp/.net/"; cp .net/hosts.orig "$tmp/etc/hosts"
mkdir -p "$tmp/now/bin" "$tmp/now/etc" "$tmp/now/.net"
cp .net/getent.orig "$tmp/now/bin/getent"; cp .net/dns.port "$tmp/now/.net/"; cp etc/hosts "$tmp/now/etc/hosts" 2>/dev/null
got=$(ask "$tmp/now" "pay-$moved.corp.example")
if [ "$got" != "127.0.20.1$moved" ]; then
  rm -rf "$tmp"
  echo "❌ app-31 resolves pay-$moved.corp.example to ${got:-nothing}, but DNS says 127.0.20.1$moved"; exit 1
fi
for name in ledger.corp.example checkout.corp.example app-31.corp.example localhost; do
  if [ "$(ask "$tmp" "$name")" != "$(ask "$tmp/now" "$name")" ]; then
    rm -rf "$tmp"
    echo "❌ $name no longer resolves as before; change only the stale entry in etc/hosts"; exit 1
  fi
done
rm -rf "$tmp"

# 5. the smoke test itself
cp .net/smoke.orig .smoke-validate.sh
out=$(bash .smoke-validate.sh 2>&1); rc=$?
rm -f .smoke-validate.sh
if [ $rc -ne 0 ]; then
  echo "❌ smoke.sh still fails: $(echo "$out" | grep -m1 FAIL)"; exit 1
fi

# 6. brief.md
[ -f brief.md ] || { echo "❌ brief.md is missing (type 'reset' for the template)"; exit 1; }
field() { sed -n "s/^[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" brief.md | head -1 | tr -d '\r`' | sed 's/[[:space:]]*$//'; }
fails=$(grep 'ERROR payments call failed' logs/checkout.log)
start=$(echo "$fails" | head -1 | cut -d' ' -f1)
end=$(echo "$fails" | tail -1 | cut -d' ' -f1)
count=$(echo "$fails" | grep -c .)
[ "$(field impact_start)" = "$start" ] || { echo "❌ brief.md impact_start is not the time of the first failed payments call in logs/checkout.log"; exit 1; }
[ "$(field impact_end)" = "$end" ] || { echo "❌ brief.md impact_end is not the time of the last failed payments call in logs/checkout.log"; exit 1; }
if [ "$(field failed_calls)" != "$count" ]; then
  echo "❌ brief.md failed_calls is not the number of failed payments calls (other ERROR and WARN lines don't count)"; exit 1
fi
[ "$(field new_port)" = "$newport" ] || { echo "❌ brief.md new_port is not the port payments moved to"; exit 1; }
rb=$(field removed_backend); rb=${rb%.corp.example}
[ "$rb" = "pay-$sick" ] || { echo "❌ brief.md removed_backend is not the backend you took out"; exit 1; }
rc_text=$(field root_cause)
if ! echo "$rc_text" | grep -qiE 'CHG-7001|port'; then
  echo "❌ brief.md root_cause should name the change that started it: compare the first failure with changes.log"; exit 1
fi
[ ${#rc_text} -ge 10 ] || { echo "❌ brief.md root_cause needs a sentence"; exit 1; }
fx=$(field fix)
[ ${#fx} -ge 10 ] || { echo "❌ brief.md fix: say in one line what you changed"; exit 1; }
echo "✅ checkout reaches payments again (smoke test passes) and the brief matches the evidence"
