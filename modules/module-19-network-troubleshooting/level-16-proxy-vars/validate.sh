#!/bin/bash
# $1 = sandbox path
# Loads proxy.env in a clean environment, checks that all six variables are
# set (both spellings, same values, proxies pointing at the proxy), then
# makes real curl calls with unique paths and reads both servers' logs:
# the vendor URL must reach the proxy, the four internal URLs must reach the
# reports service directly and never the proxy.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
P=$(cat .net/proxy.port) R=$(cat .net/reports.port)

[ -f proxy.env ] || { echo "❌ proxy.env is missing"; exit 1; }
load() { env -i PATH="$PATH" HOME="$HOME" bash -c '. ./proxy.env >/dev/null 2>&1; '"$1"; }

for v in http_proxy https_proxy no_proxy; do
  V=$(echo "$v" | tr a-z A-Z)
  lo=$(load "printf %s \"\$$v\"") up=$(load "printf %s \"\$$V\"")
  [ -n "$lo" ] || { echo "❌ $v is not set after loading proxy.env (curl and wget read the lower-case names)"; exit 1; }
  [ -n "$up" ] || { echo "❌ $V is not set after loading proxy.env (some tools read only the upper-case names)"; exit 1; }
  [ "$lo" = "$up" ] || { echo "❌ $v and $V have different values; tools would behave differently"; exit 1; }
  if [ "$v" != no_proxy ]; then
    case $lo in
      http://127.0.0.1:$P|http://127.0.0.1:$P/|http://localhost:$P|http://localhost:$P/) ;;
      *) echo "❌ $v should point at the proxy (http://127.0.0.1:$P)"; exit 1 ;;
    esac
  fi
done

tok="v$RANDOM$RANDOM"
seen() {  # log, pattern: wait up to 2 s for the server to write its log line
  for _ in 1 2 3 4 5 6 7 8 9 10; do grep -qF "$2" "$1" 2>/dev/null && return 0; sleep 0.2; done
  return 1
}
resolve="--resolve reports.internal:$R:127.0.0.1 --resolve ci.build.internal:$R:127.0.0.1"

load "curl -s -o /dev/null --max-time 5 http://updates.vendor.example/$tok-ext"
if ! seen .net/proxy.log "GET http://updates.vendor.example/$tok-ext"; then
  echo "❌ http://updates.vendor.example/ no longer goes through the proxy (there is no direct internet here)"; exit 1
fi
for url in "http://localhost:$R/$tok-1" "http://127.0.0.1:$R/$tok-2" "http://reports.internal:$R/$tok-3" "http://ci.build.internal:$R/$tok-4"; do
  load "curl -s -o /dev/null --max-time 5 $resolve $url"
  path="/${url#http://*/}"
  host=${url#http://}; host=${host%%:*}
  if grep -qF "$tok-${url##*-}" .net/proxy.log || ! seen .net/reports.log "GET $path "; then
    case $host in
      *.internal) echo "❌ curl still sends $host through the proxy; how does curl read the entries in no_proxy?" ;;
      *) echo "❌ curl still sends $host through the proxy; which no_proxy variable does curl read when both are set?" ;;
    esac
    exit 1
  fi
done
echo "✅ external traffic uses the proxy, internal traffic goes direct, and both spellings agree"
