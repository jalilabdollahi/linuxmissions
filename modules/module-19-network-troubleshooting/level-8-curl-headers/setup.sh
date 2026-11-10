#!/bin/bash
# The status site behind a chain of redirects. The final page answers GET
# with the current ETag and Cache-Control, but HEAD with the values of the
# previous build, and the first redirect carries its own Cache-Control.
# Paths, build ids, max-age values and the number of hops change per setup.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/http_server.py" "$NET/"

python3 - "$NET" <<'PY'
import json, random, sys
net = sys.argv[1]
h = lambda n: "".join(random.choice("0123456789abcdef") for _ in range(n))
build, old = h(7), h(7)
age_get = random.choice([600, 900, 1200, 1800, 2700])
age_head = random.choice([43200, 86400, 172800])
final = f"/s/{build}/index.html"
routes = [{"path": "/status", "status": 301, "redirect": "/status/",
           "headers": {"Cache-Control": "max-age=3600"}}]
if random.random() < 0.5:
    routes.append({"path": "/status/", "status": 302, "redirect": "/status/current"})
    routes.append({"path": "/status/current", "status": 302, "redirect": final,
                   "headers": {"Cache-Control": "no-store"}})
    hops = 3
else:
    routes.append({"path": "/status/", "status": 302, "redirect": final,
                   "headers": {"Cache-Control": "no-store"}})
    hops = 2
page = f"<!doctype html><title>Status</title><h1>All systems operational</h1><!-- build {build} -->\n"
routes.append({"path": final, "body": page, "content_type": "text/html; charset=utf-8",
               "headers": {"Cache-Control": f"public, max-age={age_get}", "ETag": f'"{build}"'},
               "by_method": {"HEAD": {"headers": {"Cache-Control": f"public, max-age={age_head}",
                                                  "ETag": f'"{old}"'}}}})
routes.append({"path": f"/s/{old}/index.html", "status": 410, "body": "gone\n"})
json.dump({"server": "nginx/1.24.0", "routes": routes}, open(f"{net}/http.json", "w"), indent=1)
open(f"{net}/expected", "w").write(
    f"FINAL_PATH={final}\nREDIRECTS={hops}\nMAX_AGE={age_get}\nETAG={build}\n"
    f"HEAD_AGE={age_head}\nHEAD_ETAG={old}\n")
PY

python3 "$NET/http_server.py" --config "$NET/http.json" --log "$NET/access.log" \
    --port-file "$NET/http.port" --daemon \
  || { echo "could not start the web server" >&2; exit 1; }
echo "http://127.0.0.1:$(cat "$NET/http.port")/status" > "$SANDBOX/url.txt"

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-2207  Customers see an old status page
---------------------------------------------
After this morning's deploy, customers still see yesterday's status page,
and our uptime check (which uses `curl -I`) claims the old build is still
being served. The public link is in url.txt (the web server runs on this
host, 127.0.0.1).

For the CDN team, write headers.env with what a browser gets when it
opens that link:

  FINAL_URL   the URL the browser ends up on after all redirects
  REDIRECTS   how many redirects it followed to get there
  MAX_AGE     the max-age (seconds) in the Cache-Control of the final page
  ETAG        the ETag of the final page
EOF
