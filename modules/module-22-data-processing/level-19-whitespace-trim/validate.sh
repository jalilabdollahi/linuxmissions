#!/bin/bash
# users_clean.tsv = users.tsv with, in every field, U+00A0 turned into a space,
# runs of spaces squeezed to one, leading/trailing spaces removed; LF line
# endings; only the first record of each username.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/users.sum ] || [ "$(cksum < users.tsv 2>/dev/null)" != "$(cat .lm-state/users.sum)" ]; then
  echo "❌ users.tsv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f users_clean.tsv ]; then
  echo "❌ users_clean.tsv does not exist yet"
  exit 1
fi

python3 - <<'PY'
import re, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def clean(field):
    return re.sub(" +", " ", field.replace(" ", " ")).strip(" ")

out, seen = [], set()
for line in open("users.tsv", encoding="utf-8", newline="").read().split("\n"):
    if line == "":
        continue
    fields = [clean(f) for f in line.rstrip("\r").split("\t")]
    if fields[0] in seen:
        continue
    seen.add(fields[0])
    out.append(fields)
want = "".join("\t".join(f) + "\n" for f in out)

data = open("users_clean.tsv", "rb").read()
try:
    got = data.decode("utf-8")
except UnicodeDecodeError:
    fail("users_clean.tsv is not valid UTF-8 any more; a byte of a multi-byte character was cut (check names like José or Søren)")
if got == want or got == want.rstrip("\n"):
    print("✅ users_clean.tsv has %d clean, unique users" % (len(out) - 1))
    sys.exit(0)
if "\r" in got:
    fail("users_clean.tsv still has carriage returns (\\r) from the lines that end in CRLF")
if " " in got:
    fail("users_clean.tsv still has non-breaking spaces (U+00A0, bytes c2 a0); they look like spaces but [[:space:]] and ' ' don't match them")
lines = [l for l in got.split("\n") if l != ""]
rows = [l.split("\t") for l in lines]
if any(len(r) != 5 for r in rows):
    fail("every line must keep its 5 tab-separated fields (empty ones too)")
if any(f != f.strip(" \t") for r in rows for f in r):
    fail("some fields still start or end with spaces")
if any("  " in f for r in rows for f in r):
    fail("some fields still have runs of several spaces inside; squeeze them to one")
names = [r[0] for r in rows]
if len(names) != len(set(names)):
    fail("some usernames appear more than once; keep only the first record of each user")
if not any(ch in got for ch in "éëøçİıüš") and any(ch in want for ch in "éëøçİıüš"):
    fail("the accented letters are gone (José, Søren, Kovač); only whitespace should change")
if rows and rows[0] != out[0]:
    fail("the first line must be the cleaned header line")
if len(rows) != len(out):
    fail("users_clean.tsv has %d data lines, expected %d (one per user, the first record wins)" % (len(rows) - 1, len(out) - 1))
for r, w in zip(rows, out):
    if r != w:
        if r[0] == w[0]:
            fail("the record of %s is not users.tsv's first record for that user, cleaned" % w[0])
        fail("the users are not in the order of users.tsv (first record of %s expected where %s is)" % (w[0], r[0]))
fail("users_clean.tsv differs from the cleaned export")
PY
