#!/bin/bash
# Parses secret.yaml with python3 + yaml, then decodes each value and compares
# the bytes with the sources saved in .lm-state.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f secret.yaml ] || { echo "❌ secret.yaml does not exist yet"; exit 1; }
python3 - "$SANDBOX" <<'PY'
import base64, binascii, sys, yaml
st = sys.argv[1] + "/.lm-state/"
def fail(msg):
    print("❌ " + msg); sys.exit(1)
try:
    doc = yaml.safe_load(open("secret.yaml", encoding="utf-8"))
except Exception as e:
    fail("secret.yaml is not valid YAML (%s)" % str(e).splitlines()[0][:80])
if not isinstance(doc, dict):
    fail("secret.yaml is not a YAML mapping")
for k, v in (("apiVersion", "v1"), ("kind", "Secret"), ("type", "Opaque")):
    if doc.get(k) != v:
        fail("%s should be %s, found %r" % (k, v, doc.get(k)))
if (doc.get("metadata") or {}).get("name") != "app-secrets":
    fail("metadata name should be app-secrets")
data = doc.get("data")
if not isinstance(data, dict):
    fail("there is no data: section with keys under it")
want = {"db-password": open(st + "password.txt", "rb").read().split(b"\n")[0],
        "tls.crt": open(st + "tls.crt", "rb").read(),
        "logo.png": open(st + "logo.png", "rb").read()}
if set(data) != set(want):
    fail("data has the keys %s, expected exactly %s" % (sorted(data), sorted(want)))
raw = open("secret.yaml", encoding="utf-8").read().splitlines()
for key, src in want.items():
    val = data[key]
    if not isinstance(val, str) or any(c.isspace() for c in val):
        fail("the value of %s is not one unbroken string (wrapped or split over lines?)" % key)
    line = [l for l in raw if l.strip().startswith(key + ":")]
    if len(line) != 1 or line[0].split(":", 1)[1].strip() != val:
        fail("the value of %s must sit on the same line as its key" % key)
    try:
        got = base64.b64decode(val, validate=True)
    except (binascii.Error, ValueError):
        fail("the value of %s is not valid base64" % key)
    if got != src:
        if got == src + b"\n":
            fail("%s decodes to the source plus one extra byte at the end" % key)
        fail("%s does not decode to the bytes of its source (%d bytes decoded, %d expected)" % (key, len(got), len(src)))
print("✅ secret.yaml holds all three values, each decoding to its source byte for byte")
PY
exit $?
