#!/bin/bash
# sensors.bin: 8-byte file header ("SNSR" + u32 record count) followed by
# 16-byte records: u32 timestamp, u16 sensor, u16 status, f32 value, u32 crc,
# all little-endian. python3 only packs the bytes; .lm-state/expected is the
# decoded answer.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > FORMAT.txt <<'TXT'
sensors.bin: boiler sensor log

File header (8 bytes)
  0   4  magic "SNSR"
  4   4  u32  number of records

Then one record per 16 bytes, no padding between records:
  +0  4  u32  timestamp (unix seconds)
  +4  2  u16  sensor id
  +6  2  u16  status (0 = ok, anything else = fault code)
  +8  4  f32  value (IEEE 754 single precision)
  +12 4  u32  crc of the first 12 bytes

All numbers are little-endian.
TXT
python3 - <<'PY'
import random, struct, zlib
n = random.randint(70, 110)
ts = 1790000000 + random.randint(0, 100000)
recs = []
faulty = set(random.sample(range(n), random.randint(7, 11)))
out = bytearray(b"SNSR" + struct.pack("<I", n))
exp = []
for i in range(n):
    ts += random.randint(5, 60)
    sensor = random.choice([3, 4, 7, 11, 12, 21, 40, 41])
    status = random.choice([1, 2, 4, 9, 17, 256]) if i in faulty else 0
    value = round(random.uniform(-20, 120), 1)
    body = struct.pack("<IHHf", ts, sensor, status, value)
    out += body + struct.pack("<I", zlib.crc32(body))
    if status:
        exp.append("%d %d %.1f" % (ts, sensor, struct.unpack("<f", struct.pack("<f", value))[0]))
open("sensors.bin", "wb").write(out)
open(".lm-state/expected", "w").write("\n".join(exp) + "\n")
PY
