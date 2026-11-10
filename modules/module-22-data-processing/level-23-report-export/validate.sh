#!/bin/bash
# export.csv: UTF-8 BOM, then RFC 4180 CSV with the same header and records
# as clean.tsv (checked with a strict parser). export.json: an array of
# objects, one per row in order, keys = header names; id and amount are JSON
# numbers, every other value (zip included) a string.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/clean.sum ] || [ "$(cksum < clean.tsv 2>/dev/null)" != "$(cat .lm-state/clean.sum)" ]; then
  echo "❌ clean.tsv was changed or removed; type 'reset' to restore it"
  exit 1
fi
for f in export.csv export.json; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

python3 - <<'PY'
import json, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows = [l.split("\t") for l in open("clean.tsv", encoding="utf-8").read().split("\n") if l]
header, data = rows[0], rows[1:]

# ---- export.csv -------------------------------------------------------
raw = open("export.csv", "rb").read()
if not raw.startswith(b"\xef\xbb\xbf"):
    fail("export.csv must start with the UTF-8 byte-order mark (bytes ef bb bf); without it Excel reads Zoë as ZoÃ«")
try:
    text = raw[3:].decode("utf-8")
except UnicodeDecodeError:
    fail("export.csv is not valid UTF-8 after the byte-order mark")
if text.startswith("﻿"):
    fail("export.csv has the byte-order mark twice")

if "\t" in text:
    fail("export.csv still has tabs: lines where no field was changed were never rebuilt with commas (in awk, $1 = $1 forces it)")

def rfc4180(t):
    recs, rec, i, n, line = [], [], 0, len(t), 1
    while True:
        if i < n and t[i] == '"':
            i += 1
            buf = []
            while True:
                if i >= n:
                    raise ValueError("record %d: a quoted field is never closed" % (len(recs) + 1))
                if t[i] == '"':
                    if i + 1 < n and t[i + 1] == '"':
                        buf.append('"'); i += 2; continue
                    i += 1
                    break
                buf.append(t[i]); i += 1
            if i < n and t[i] not in ",\r\n":
                raise ValueError("record %d: text after a closing quote (a quote inside a quoted field must be doubled: \"\")" % (len(recs) + 1))
            field = "".join(buf)
        else:
            j = i
            while i < n and t[i] not in ",\r\n":
                if t[i] == '"':
                    raise ValueError("record %d: a field with a \" in it must be in double quotes, with the \" doubled" % (len(recs) + 1))
                i += 1
            field = t[j:i]
        rec.append(field)
        if i >= n:
            if rec != [""]:
                recs.append(rec)
            return recs
        if t[i] == ",":
            i += 1
            continue
        if t[i] == "\r":
            i += 1
            if i >= n or t[i] != "\n":
                raise ValueError("record %d: a lone carriage return" % (len(recs) + 1))
        i += 1
        recs.append(rec)
        rec = []
        if i >= n:
            return recs

try:
    recs = rfc4180(text)
except ValueError as e:
    fail("export.csv is not valid CSV: %s" % e)
if not recs or recs[0] != header:
    fail("the first record of export.csv must be the header: " + ",".join(header))
if len(recs) - 1 != len(data):
    fail("export.csv has %d data records, clean.tsv has %d" % (len(recs) - 1, len(data)))
for r, w in zip(recs[1:], data):
    if len(r) != len(w):
        if len(r) > len(w):
            fail("record %s of export.csv has %d fields instead of %d: a value with a comma in it must be quoted" % (w[0], len(r), len(w)))
        fail("record %s of export.csv has %d fields instead of %d" % (w[0], len(r), len(w)))
    for name, a, b in zip(header, r, w):
        if a != b:
            fail("record %s of export.csv: the %s field reads back as %r, but clean.tsv has %r" % (w[0], name, a, b))

# ---- export.json ------------------------------------------------------
jraw = open("export.json", "rb").read()
if jraw.startswith(b"\xef\xbb\xbf"):
    fail("export.json starts with a byte-order mark; JSON must not have one (only the CSV for Excel)")
try:
    doc = json.loads(jraw.decode("utf-8"))
except (UnicodeDecodeError, ValueError) as e:
    fail("export.json is not valid JSON (%s)" % str(e).split(":")[0])
if not isinstance(doc, list):
    fail("export.json must be one JSON array of objects, e.g. [{...}, {...}], not %s" % type(doc).__name__)
if len(doc) != len(data):
    fail("export.json has %d objects, clean.tsv has %d rows" % (len(doc), len(data)))
for o, w in zip(doc, data):
    if not isinstance(o, dict):
        fail("every element of the array must be an object with the column names as keys")
    if set(o) != set(header):
        fail("the keys of every object must be exactly the column names %s; found %s" % (", ".join(header), ", ".join(sorted(o))))
    for name, b in zip(header, w):
        a = o[name]
        if name in ("id", "amount"):
            if isinstance(a, bool) or not isinstance(a, (int, float)):
                fail("%s must be a JSON number, not a string (\"%s\": %s in object %s); jq's tonumber converts" % (name, name, json.dumps(a, ensure_ascii=False), w[0]))
            if abs(a - float(b)) > 1e-9:
                fail("object %s: %s is %s, clean.tsv has %s" % (w[0], name, a, b))
        else:
            if not isinstance(a, str):
                if name == "zip":
                    fail("zip must stay a string: as a number 02134 becomes 2134 and the leading zero is lost")
                fail("%s must be a string in object %s" % (name, w[0]))
            if a != b:
                fail("object %s: %s is %r, clean.tsv has %r" % (w[0], name, a, b))
print("✅ export.csv opens cleanly in Excel and export.json has the right types, %d records each" % len(data))
PY
