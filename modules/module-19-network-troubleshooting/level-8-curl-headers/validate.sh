#!/bin/bash
SANDBOX="$1"
NET="$SANDBOX/.net"
OUT="$SANDBOX/headers.env"

if [ ! -f "$OUT" ]; then
  echo "❌ headers.env does not exist yet"
  exit 1
fi

python3 - "$NET" "$OUT" "$(cat "$NET/http.port")" <<'PY'
import sys
net, out, port = sys.argv[1:4]
def kv(path):
    d = {}
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = raw.strip().replace("\r", "")
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"" and v.count(v[0]) == 2:
                v = v[1:-1]                      # FOO="value"
            d[k.strip()] = v
    return d
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

want, got = kv(f"{net}/expected"), kv(out)
for k in ("FINAL_URL", "REDIRECTS", "MAX_AGE", "ETAG"):
    if not got.get(k):
        fail(f"headers.env has no {k}= value")

log = open(f"{net}/access.log").read() if __import__("os").path.exists(f"{net}/access.log") else ""
if f'"GET {want["FINAL_PATH"]} ' not in log:
    fail("the final page has never been fetched with GET (what a browser does) yet")

final_url = f"http://127.0.0.1:{port}{want['FINAL_PATH']}"
if got["FINAL_URL"].rstrip() != final_url:
    if got["FINAL_URL"].startswith("/"):
        fail("FINAL_URL should be the full URL (http://127.0.0.1:PORT/...), the way curl reports it")
    fail("FINAL_URL is not where the redirects end")
if got["REDIRECTS"] != want["REDIRECTS"]:
    fail(f"REDIRECTS={got['REDIRECTS']} is not the number of redirects between url.txt and the final page")

age = got["MAX_AGE"].replace("max-age=", "")
if age == want["HEAD_AGE"]:
    fail("MAX_AGE is what the server says to HEAD requests (curl -I); browsers use GET and get a different header")
if age == "3600":
    fail("MAX_AGE comes from a redirect's Cache-Control, not from the final page")
if age != want["MAX_AGE"]:
    fail("MAX_AGE is not the max-age of the final page")

etag = got["ETAG"].strip().strip('"').strip("\\").strip('"')
if etag == want["HEAD_ETAG"]:
    fail("ETAG is what the server says to HEAD requests (curl -I); a browser's GET gets a different ETag")
if etag != want["ETAG"]:
    fail("ETAG is not the ETag of the final page")
print(f"✅ {want['REDIRECTS']} redirects, final page cached for {want['MAX_AGE']} s with ETag \"{want['ETAG']}\" (HEAD still says \"{want['HEAD_ETAG']}\")")
PY
