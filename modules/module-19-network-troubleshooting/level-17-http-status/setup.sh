#!/bin/bash
# $1 = sandbox path
# One loopback web server with eleven health endpoints. Behaviours are
# shuffled over the service names per setup: fast 200/204, a 0.4-0.7 s 200
# (fine), a 1.3-2.2 s 200 (too slow), 301 and 302 redirects (bad, and -L
# would hide them), 500, 503, 404, and one that never answers (needs
# --max-time; curl then reports 000).
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/http_server.py" "$NET/"
cd "$SANDBOX" || exit 1

python3 - "$NET" <<'PY'
import json, random, sys

net = sys.argv[1]
r = random.Random()
names = ["orders", "billing", "search", "inventory", "auth", "catalog", "shipping", "reviews", "pricing", "users", "cart"]
r.shuffle(names)
slow = round(r.uniform(1.3, 2.2), 1)
okish = round(r.uniform(0.4, 0.7), 1)
kinds = [
    ("ok", {"json": {"status": "ok"}}),
    ("ok", {"body": "OK\n"}),
    ("ok204", {"status": 204, "body": ""}),
    ("okish", {"delay": okish, "json": {"status": "ok"}}),
    ("slow", {"delay": slow, "json": {"status": "ok", "note": "db pool exhausted, waited"}}),
    ("301", {"status": 301, "redirect": "/v2/health"}),
    ("302", {"status": 302, "redirect": "/login?next=/health"}),
    ("500", {"status": 500, "json": {"error": "internal"}}),
    ("503", {"status": 503, "json": {"status": "down", "reason": "maintenance"}}),
    ("404", {"status": 404, "body": "no such endpoint\n"}),
    ("hang", {"hang": True}),
]
routes, urls = [], []
for name, (kind, spec) in zip(names, kinds):
    path = f"/{name}/health"
    routes.append(dict(spec, path=path))
    urls.append((name, path, kind))
routes += [{"path": "/v2/health", "json": {"status": "ok"}}, {"path": "/login", "body": "login page\n"}]
json.dump({"server": "nginx/1.24.0", "routes": routes}, open(f"{net}/http.json", "w"), indent=1)
with open(f"{net}/urls", "w") as f:
    for name, path, kind in urls:
        f.write(f"{name} {path}\n")
PY

python3 "$NET/http_server.py" --config "$NET/http.json" --log "$NET/access.log" \
  --port-file "$NET/http.port" --idle-timeout 0 --daemon \
  || { echo "could not start the web server" >&2; exit 1; }
PORT=$(cat "$NET/http.port")

{
  echo "# health endpoints polled by the dashboard (team: platform)"
  echo "# format: one URL per line"
  echo
  n=0
  while read -r name path _; do
    n=$((n + 1))
    [ $n -eq 6 ] && printf '\n# --- added by the commerce squad ---\n'
    if [ "$name" = "$(sed -n 3p "$NET/urls" | cut -d' ' -f1)" ]; then
      echo "http://127.0.0.1:$PORT$path?verbose=1"
    else
      echo "http://127.0.0.1:$PORT$path"
    fi
  done < <(sort -R "$NET/urls")
} > endpoints.txt

cat > TICKET.txt <<'EOF'
OPS-2290  Health dashboard is red, but which ones?

The dashboard just says "degraded". Check every URL in endpoints.txt
yourself (the services run on this machine) and write status.tsv with one
line per URL:

  URL<TAB>HTTP_CODE<TAB>TIME_SECONDS

HTTP_CODE is the code the URL itself answers (do not follow redirects; use
000 if no response arrives within a few seconds) and TIME_SECONDS is the
total time of the request.

Then write bad.txt with the URLs (one per line) that need attention:
anything that isn't a 2xx answer (redirects, errors, no answer) and
anything that took longer than 1 second.
EOF
