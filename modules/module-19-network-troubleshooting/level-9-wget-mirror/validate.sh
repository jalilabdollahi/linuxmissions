#!/bin/bash
# The mirror must hold exactly the docs files (robots.txt may sit next to
# them), with the right content, and every link between docs files must be a
# relative link to a file that exists in the mirror.
SANDBOX="$1"

if [ ! -d "$SANDBOX/mirror" ]; then
  echo "❌ mirror/ does not exist yet"
  exit 1
fi

python3 - "$SANDBOX" "$(cat "$SANDBOX/.net/http.port")" <<'PY'
import hashlib, os, re, sys
sb, port = sys.argv[1], sys.argv[2]
mirror, site = f"{sb}/mirror", f"{sb}/.net/site/docs"
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

want = set(open(f"{sb}/.net/expected").read().split())
have = set()
for root, dirs, files in os.walk(mirror):
    for f in files:
        have.add(os.path.relpath(os.path.join(root, f), mirror))
have.discard("robots.txt")
if not have:
    fail("mirror/ is empty")

if any(p.startswith("127.0.0.1") for p in have):
    fail("mirror/ has a host-name folder (127.0.0.1...): the docs root should be mirror/ itself")
if any(p.startswith("docs/") for p in have):
    fail("mirror/ has a docs/ folder in between: the docs start page should be mirror/index.html")
if any("old/" in p for p in have):
    fail("mirror/ contains pages under /docs/old/, which robots.txt asks crawlers to skip")
outside = [p for p in have - want if not p.startswith("old/")]
if outside:
    fail(f"mirror/ has files that are not part of /docs/ (e.g. {sorted(outside)[0]}): the crawl went above the docs folder")
missing = sorted(want - have)
if missing:
    fail(f"mirror/ is missing {len(missing)} docs file(s), e.g. {missing[0]}")

for rel in sorted(want):
    got = open(f"{mirror}/{rel}", "rb").read()
    orig = open(f"{site}/{rel}", "rb").read()
    if not rel.endswith(".html"):
        if hashlib.sha256(got).digest() != hashlib.sha256(orig).digest():
            fail(f"mirror/{rel} differs from the file on the server")
        continue
    pid = re.search(rb"page-id: \w+", orig).group(0)
    if pid not in got:
        fail(f"mirror/{rel} is not the page that lives at /docs/{rel}")
    here = os.path.dirname(rel)
    for link in re.findall(r'(?:href|src)="([^"]*)"', got.decode("utf-8", "replace")):
        target = link.split("#")[0].split("?")[0]
        if not target:
            continue
        absolute = re.match(rf"(https?://(127\.0\.0\.1|localhost):{port})?(/.*)$", target)
        if absolute:
            path = absolute.group(3)
            if path.startswith("/docs/") and not path.startswith("/docs/old/"):
                fail(f"mirror/{rel} still links to the server ({link}); offline that link is dead. Have wget rewrite links")
            continue
        if re.match(r"\w+:", target):
            continue
        resolved = os.path.normpath(os.path.join(here, target))
        if not os.path.isfile(f"{mirror}/{resolved}"):
            fail(f"mirror/{rel} links to {link}, which does not exist in mirror/")
print(f"✅ mirror/ holds the {len(want)} docs files with working relative links, nothing else")
PY
