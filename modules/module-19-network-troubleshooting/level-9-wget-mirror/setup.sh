#!/bin/bash
# The old documentation site on 127.0.0.1: /docs/ (to be mirrored), plus
# /blog/ and /admin/ that the docs link to, and /docs/old/ which robots.txt
# disallows. Page names, page ids and asset bytes change per setup; the list
# of files a correct mirror holds goes to .net/expected.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/http_server.py" "$NET/"

python3 - "$NET" <<'PY'
import json, os, random, sys
net = sys.argv[1]
site = f"{net}/site"
pid = lambda: "".join(random.choice("0123456789abcdef") for _ in range(10))
guides = ["install"] + random.sample(["upgrade", "backup", "tuning", "ldap", "migration", "ha-setup"], 2)
apis = ["index"] + random.sample(["endpoints", "auth", "errors", "webhooks"], 2)

def page(title, body_links, extra=""):
    links = "\n".join(f'    <li><a href="{h}">{t}</a></li>' for h, t in body_links)
    return (f"<!doctype html>\n<html><head><meta charset=\"utf-8\"><title>{title}</title>\n"
            f"<link rel=\"stylesheet\" href=\"/docs/static/site.css\"></head>\n<body>\n"
            f"<!-- page-id: {pid()} -->\n<h1>{title}</h1>\n{extra}<ul>\n{links}\n</ul>\n</body></html>\n")

files = {}
files["docs/index.html"] = page("Orbit Docs", [(f"/docs/guide/{g}.html", g.title()) for g in guides] + [
    ("/docs/api/", "API reference"), ("/docs/old/v1.html", "Docs for v1 (archived)"),
    ("/blog/", "Blog"), ("/admin/", "Admin"), ("../", "Home")],
    '<img src="/docs/static/architecture.png" alt="architecture">\n')
for i, g in enumerate(guides):
    nxt = guides[(i + 1) % len(guides)]
    files[f"docs/guide/{g}.html"] = page(f"Guide: {g}", [
        ("/docs/", "Docs home"), (f"{nxt}.html", f"Next: {nxt}"), ("../api/", "API"),
        ("/blog/2026/release-notes.html", "Release notes")])
for a in apis:
    files[f"docs/api/{a}.html"] = page(f"API: {a}", [
        (f"/docs/api/{b}.html", b) for b in apis if b != a] + [("/docs/", "Docs home")],
        '<script src="/docs/static/search.js"></script>\n')
files["docs/old/v1.html"] = page("v1 (archived)", [("/docs/old/v0.html", "v0")])
files["docs/old/v0.html"] = page("v0 (archived)", [("/docs/", "current docs")])
files["blog/index.html"] = page("Blog", [("/blog/2026/release-notes.html", "Release notes"), ("/docs/", "Docs")])
files["blog/2026/release-notes.html"] = page("Release notes", [("/blog/", "Blog")])
files["admin/index.html"] = page("Admin", [("/admin/users.html", "Users")])
files["admin/users.html"] = page("Users", [])
files["docs/static/site.css"] = "body { font-family: sans-serif; max-width: 50em; margin: auto }\n/* %s */\n" % pid()
files["docs/static/search.js"] = "// search %s\nwindow.search = q => fetch('/docs/api/search?q=' + q);\n" % pid()
for path, text in files.items():
    os.makedirs(os.path.dirname(f"{site}/{path}"), exist_ok=True)
    open(f"{site}/{path}", "w").write(text)
png = b"\x89PNG\r\n\x1a\n" + os.urandom(random.randint(3000, 6000))
open(f"{site}/docs/static/architecture.png", "wb").write(png)

routes = [
    {"path": "/robots.txt", "body": "User-agent: *\nDisallow: /docs/old/\nDisallow: /admin/\n"},
    {"path": "/docs*", "dir": "site/docs"},
    {"path": "/blog*", "dir": "site/blog"},
    {"path": "/admin*", "dir": "site/admin"},
    {"path": "/", "body": "<!doctype html><title>Orbit</title><a href=\"/docs/\">Docs</a> <a href=\"/blog/\">Blog</a>\n",
     "content_type": "text/html"},
]
json.dump({"server": "nginx/1.18.0", "routes": routes}, open(f"{net}/http.json", "w"), indent=1)
want = sorted(p[len("docs/"):] for p in list(files) + ["docs/static/architecture.png"]
              if p.startswith("docs/") and not p.startswith("docs/old/"))
open(f"{net}/expected", "w").write("\n".join(want) + "\n")
PY

python3 "$NET/http_server.py" --config "$NET/http.json" --log "$NET/access.log" \
    --port-file "$NET/http.port" --daemon \
  || { echo "could not start the web server" >&2; exit 1; }
echo "http://127.0.0.1:$(cat "$NET/http.port")/docs/" > "$SANDBOX/docs-url.txt"

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-4410  Keep an offline copy of the Orbit docs
---------------------------------------------------
The old docs server is switched off on Friday. Support wants an offline
copy of the documentation (the /docs/ tree, URL in docs-url.txt) in the
folder mirror/, so that opening mirror/index.html in a browser works and
every link between the docs pages and to their CSS, script and images
works without the server.

- mirror/ is the docs root: the start page is mirror/index.html, the
  guide pages are in mirror/guide/ and so on (no host-name folder, no
  docs/ folder in between).
- Only the docs. The blog and the admin pages are not part of it, even
  though the docs link to them.
- The site's robots.txt asks crawlers to stay out of some paths; respect it.
EOF
