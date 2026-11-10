#!/usr/bin/env python3
"""Level-local helper: write one build directory for the promotion level.

  mkbuild.py DIR VERSION [--sig ok|badkey|tampered] [--checksum ok|bad]
                         [--changelog ok|missing] [--layout ok|mode|notop|junk|owner]

DIR gets agent-VERSION.tar.gz, SHA256SUMS, SHA256SUMS.sig (detached, signed with the test key1
unless --sig badkey) and CHANGELOG.md. Each flag breaks exactly one gate.
"""
import argparse, gzip, hashlib, io, os, sys, tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "mocks", "packages"))
import pgp  # noqa: E402

EPOCH = 1767225600


def tarball(version, readme, layout):
    top = f"agent-{version}"
    files = {
        "bin/agentd": (b"#!/bin/sh\necho agentd " + version.encode() + b"\n", 0o755),
        "bin/agentctl": (b"#!/bin/sh\necho agentctl\n", 0o755),
        "conf/agent.conf": (b"listen = 127.0.0.1:7070\n", 0o640),
        "lib/helpers.sh": (b"log() { echo \"$*\"; }\n", 0o644),
        "README.md": (readme, 0o644),
    }
    if layout == "mode":
        files["conf/agent.conf"] = (files["conf/agent.conf"][0], 0o644)
    if layout == "junk":
        files["lib/.DS_Store"] = (b"\x00Bud1", 0o644)
    members = []
    dirs = sorted({os.path.dirname(p) for p in files if os.path.dirname(p)} | {""})
    prefix = "" if layout == "notop" else top + "/"
    for d in dirs:
        if layout == "notop" and d == "":
            continue
        members.append((prefix + d + ("/" if d else ""), None, 0o755))
    for p, (data, mode) in files.items():
        members.append((prefix + p, data, mode))
    members.sort(key=lambda m: m[0].encode())
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.GNU_FORMAT) as tf:
        for name, data, mode in members:
            ti = tarfile.TarInfo(name.rstrip("/") if data is None else name)
            ti.mtime = EPOCH
            ti.mode = mode
            ti.uid = 1000 if layout == "owner" and name.endswith("agentd") else 0
            ti.gid = 0
            ti.uname = ti.gname = ""
            if data is None:
                ti.type = tarfile.DIRTYPE
                tf.addfile(ti)
            else:
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
    raw = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as g:
        g.write(buf.getvalue())
    return raw.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("version")
    ap.add_argument("--sig", default="ok")
    ap.add_argument("--checksum", default="ok")
    ap.add_argument("--changelog", default="ok")
    ap.add_argument("--layout", default="ok")
    a = ap.parse_args()
    os.makedirs(a.dir, exist_ok=True)
    name = f"agent-{a.version}.tar.gz"
    good = tarball(a.version, b"# agent\n", a.layout)
    sums = f"{hashlib.sha256(good).hexdigest()}  {name}\n".encode()
    art = good if a.checksum == "ok" else tarball(a.version, b"# agent (rebuilt by someone)\n", a.layout)
    open(os.path.join(a.dir, name), "wb").write(art)
    key = pgp.load_key("key2" if a.sig == "badkey" else "key1")
    sig = pgp.detach_sign(key, sums, armor=True)
    if a.sig == "tampered":
        sums += b"# regenerated after review\n"
    open(os.path.join(a.dir, "SHA256SUMS"), "wb").write(sums)
    open(os.path.join(a.dir, "SHA256SUMS.sig"), "wb").write(sig)
    major, minor, patch = (int(x) for x in a.version.split(".")[:3])
    if a.changelog == "ok":
        cl = (f"# Changelog\n\n## {a.version} - 2026-11-03\n- Fix reload race\n\n"
              f"## {major}.{minor}.{max(patch - 1, 0)} - 2026-10-20\n- Add health probe\n")
    else:
        cl = (f"# Changelog\n\n## Unreleased\n- Fix reload race (will ship as {a.version})\n\n"
              f"## {major}.{minor}.{patch * 10 + 1} - 2026-10-30\n- Plan for a later line\n\n"
              f"## {major}.{minor}.{max(patch - 1, 0)} - 2026-10-20\n- Add health probe, regression of {a.version} avoided\n")
    open(os.path.join(a.dir, "CHANGELOG.md"), "w").write(cl)


main()
