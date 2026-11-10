#!/bin/bash
SANDBOX="$1"
NET="$SANDBOX/.net"
OUT="$SANDBOX/results.tsv"

if [ ! -f "$OUT" ]; then
  echo "❌ results.tsv does not exist yet"
  exit 1
fi

while IFS=$'\t' read -r name want; do
  if ! grep -q " $name\. A " "$NET/query.log" 2>/dev/null; then
    echo "❌ nobody has asked the DNS server about $name yet"
    exit 1
  fi
done < "$NET/expected.tsv"

python3 - "$NET/expected.tsv" "$OUT" <<'PY'
import sys
want = dict(l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip())
got = {}
for raw in open(sys.argv[2], encoding="utf-8", errors="replace"):
    w = raw.replace("\r", "").split()
    if not w:
        continue
    if len(w) != 2:
        print(f"❌ line '{raw.strip()}' should be NAME<TAB>STATUS")
        sys.exit(1)
    name = w[0].rstrip(".").lower()
    if name in got:
        print(f"❌ {name} appears twice in results.tsv")
        sys.exit(1)
    got[name] = w[1]
for name in want:
    if name not in got:
        print(f"❌ results.tsv has no line for {name}")
        sys.exit(1)
extra = [n for n in got if n not in want]
if extra:
    print(f"❌ {extra[0]} is not in names.txt")
    sys.exit(1)
for name, status in got.items():
    if status not in ("OK", "NXDOMAIN", "SERVFAIL", "TIMEOUT"):
        print(f"❌ {name}: status must be one of OK, NXDOMAIN, SERVFAIL, TIMEOUT (got {status})")
        sys.exit(1)
wrong = [n for n in want if got[n] != want[n]]
if wrong:
    n = wrong[0]
    print(f"❌ {n} is not {got[n]}; read nslookup's message for it again" + (f" ({len(wrong)} names are wrong)" if len(wrong) > 1 else ""))
    sys.exit(1)
print("✅ every name has the status the resolver really gave")
PY
