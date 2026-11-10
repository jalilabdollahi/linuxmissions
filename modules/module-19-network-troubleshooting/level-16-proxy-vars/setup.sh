#!/bin/bash
# $1 = sandbox path
# Two loopback web servers: the corporate forward proxy (serves the vendor
# sites, answers 403 for anything internal) and the internal reports service.
# proxy.env is the half-right config from the wiki:
#   - lower-case no_proxy=*.internal (curl ignores "*." patterns, and the
#     lower-case variable wins over NO_PROXY, so localhost is proxied too)
#   - only http_proxy and HTTPS_PROXY are set, so tools that read the other
#     spelling see no proxy at all
# External downloads work, every internal call ends at the proxy's 403.
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/http_server.py" "$NET/"
cd "$SANDBOX" || exit 1

build="$(( RANDOM % 900 + 100 ))"
cat > "$NET/proxy.json" <<EOF
{
  "server": "squid/6.6",
  "routes": [
    {"path": "/*", "host": "updates.vendor.example", "body": "vendor update index, build $build\n"},
    {"path": "/*", "host": "downloads.vendor.example", "body": "vendor downloads\n"},
    {"path": "/*", "status": 403, "reason": "Forbidden",
     "headers": {"X-Squid-Error": "ERR_ACCESS_DENIED 0"},
     "body": "ERROR: The requested URL could not be retrieved\nAccess control configuration prevents your request from being allowed at this time.\n"}
  ]
}
EOF
cat > "$NET/reports.json" <<'EOF'
{
  "server": "reports/3.2.0",
  "routes": [
    {"path": "/health", "json": {"service": "reports", "status": "ok"}},
    {"path": "/*", "json": {"service": "reports", "report": "daily-sales", "rows": 1312}}
  ]
}
EOF
python3 "$NET/http_server.py" --config "$NET/proxy.json" --log "$NET/proxy.log" \
  --port-file "$NET/proxy.port" --idle-timeout 0 --daemon \
  || { echo "could not start the proxy" >&2; exit 1; }
python3 "$NET/http_server.py" --config "$NET/reports.json" --log "$NET/reports.log" \
  --port-file "$NET/reports.port" --idle-timeout 0 --daemon \
  || { echo "could not start the reports service" >&2; exit 1; }
P=$(cat "$NET/proxy.port")
R=$(cat "$NET/reports.port")

cat > proxy.env <<EOF
# Corporate proxy (NET-2231). Every job does: . ./proxy.env
# Copied from the wiki page "Using the proxy on Linux".
export http_proxy=http://127.0.0.1:$P
export HTTPS_PROXY=http://127.0.0.1:$P
export NO_PROXY=localhost,127.0.0.1,*.internal
export no_proxy=*.internal
EOF

cat > services.txt <<EOF
# What jobs on this host talk to
external  http://updates.vendor.example/            must go through the proxy (no direct internet)
internal  http://localhost:$R/health                 reports service, local port
internal  http://127.0.0.1:$R/health                 same, by address
internal  http://reports.internal:$R/health          same, by its DNS name
internal  http://ci.build.internal:$R/health         build cache (same box in this lab)

There is no DNS for *.internal in this lab. Make curl resolve the names to
this machine with --resolve, e.g.
  curl --resolve reports.internal:$R:127.0.0.1 http://reports.internal:$R/health
EOF

cat > check-access.sh <<EOF
#!/bin/bash
# Loads proxy.env and calls everything in services.txt the way the jobs do.
cd "\$(dirname "\$0")" || exit 1
. ./proxy.env
check() {
  out=\$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' --resolve reports.internal:$R:127.0.0.1 \\
        --resolve ci.build.internal:$R:127.0.0.1 "\$1")
  if [ "\$out" = 200 ]; then echo "OK    \$1"; else echo "FAIL  \$1 (HTTP \$out)"; fi
}
check http://updates.vendor.example/
check http://localhost:$R/health
check http://127.0.0.1:$R/health
check http://reports.internal:$R/health
check http://ci.build.internal:$R/health
EOF
chmod +x check-access.sh

cat > TICKET.txt <<'EOF'
NET-2240  Since the proxy rollout, internal calls fail

Since NET-2231 added proxy.env to every job, downloads from the vendor work
but every call to our own services fails with "403 Forbidden" from squid.
./check-access.sh shows it.

Fix proxy.env: external hosts through the proxy, internal ones (localhost,
127.0.0.1, anything under .internal) directly. Some of our tools read the
lower-case variables and some only the upper-case ones, so set both
spellings of http_proxy, https_proxy and no_proxy, with the same values.
EOF
