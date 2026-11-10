#!/usr/bin/env python3
"""LinuxMissions package world: real apt and dpkg on a sandbox root.

Builds a self-contained Debian package world inside a level sandbox and
installs wrappers named like the real tools (apt, apt-get, apt-cache,
apt-mark, apt-config, apt-key, dpkg, dpkg-query) that run the REAL programs
against it, as a normal user, offline:

* apt reads APT_CONFIG=<root>/etc/apt/apt.conf, which points every Dir:: at
  the sandbox root, turns off locking, and makes apt call dpkg with
  --root=<root> --force-not-root ...; so `apt-get install`, `remove`,
  `purge`, `upgrade`, `update`, `apt-mark hold` really happen, with real
  dependency resolution, output, /var/log/apt/history.log, term.log and
  /var/log/dpkg.log, all inside the sandbox;
* repositories are local `file:` archives with real .deb files (built with
  dpkg-deb), Packages/Release indexes and, if asked, InRelease/Release.gpg
  signed with the committed test keys (see pgp.py);
* the only simulated part is the "Do you want to continue? [Y/n]" prompt:
  the game's shell cannot answer it, so when output goes to a terminal the
  apt/apt-get wrapper answers it (default Y, or $LM_APT_ANSWER) and shows
  the answer, like a user typing it.

Linux only (needs dpkg, dpkg-deb and apt; all in the reference image).

  python3 pkgsim.py build SANDBOX FIXTURE.json [--no-update] [--repos-only]
  python3 pkgsim.py sign-file KEY FILE        (InRelease-style, to stdout)

The fixture format is documented in mocks/README.md.
"""
from __future__ import annotations

import datetime as dt
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, HERE)

REAL = {t: f"/usr/bin/{t}" for t in ("apt", "apt-get", "apt-cache", "apt-mark", "apt-config",
                                     "apt-key", "dpkg", "dpkg-query", "dpkg-deb")}
WRAPPED = ("apt", "apt-get", "apt-cache", "apt-mark", "apt-config", "apt-key", "dpkg", "dpkg-query")
DEFAULT_MAINTAINER = "Example Packagers <packages@example.org>"
CONTROL_ORDER = ["Package", "Source", "Version", "Architecture", "Maintainer", "Installed-Size",
                 "Pre-Depends", "Depends", "Recommends", "Suggests", "Enhances", "Conflicts", "Breaks",
                 "Replaces", "Provides", "Section", "Priority", "Multi-Arch", "Essential", "Homepage",
                 "Description"]
SPEC_FIELDS = {"source": "Source", "maintainer": "Maintainer", "pre_depends": "Pre-Depends",
               "depends": "Depends", "recommends": "Recommends", "suggests": "Suggests",
               "enhances": "Enhances", "conflicts": "Conflicts", "breaks": "Breaks",
               "replaces": "Replaces", "provides": "Provides", "section": "Section",
               "priority": "Priority", "multi_arch": "Multi-Arch", "essential": "Essential",
               "homepage": "Homepage"}
BASE_DIRS = ["/etc", "/etc/default", "/opt", "/srv", "/usr", "/usr/bin", "/usr/sbin", "/usr/lib",
             "/usr/include", "/usr/local", "/usr/local/bin", "/usr/local/sbin", "/usr/local/lib",
             "/usr/share", "/usr/share/doc", "/usr/share/man", "/usr/share/man/man1",
             "/usr/share/man/man5", "/usr/share/man/man8", "/var", "/var/backups", "/var/cache",
             "/var/lib", "/var/local", "/var/log", "/var/opt", "/var/spool", "/var/tmp"]
WANT = {"u": "unknown", "i": "install", "h": "hold", "r": "deinstall", "p": "purge"}
STATE = {"n": "not-installed", "c": "config-files", "H": "half-installed", "U": "unpacked",
         "F": "half-configured", "W": "triggers-awaited", "t": "triggers-pending", "i": "installed"}


class FixtureError(Exception):
    pass


# ─── helpers ────────────────────────────────────────────────────────────────

def native_arch() -> str:
    try:
        return subprocess.run([REAL["dpkg"], "--print-architecture"], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "amd64"


def run(cmd, **kw):
    kw.setdefault("capture_output", True)
    kw.setdefault("text", True)
    return subprocess.run(cmd, **kw)


def under(root: str, path: str) -> str:
    """Map an absolute in-root path ('/etc/x') to the real path inside root."""
    return os.path.join(root, path.lstrip("/"))


def file_bytes(spec) -> tuple[bytes | None, dict]:
    """A file spec (string or dict) -> (content bytes or None, the dict form)."""
    if isinstance(spec, str):
        return spec.encode("utf-8"), {}
    if spec is None:
        return b"", {}
    if "symlink" in spec or spec.get("dir"):
        return None, spec
    if "base64" in spec:
        import base64
        data = base64.b64decode(spec["base64"])
    elif "gzip" in spec:
        buf = io.BytesIO()
        with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0, filename="") as g:
            g.write(spec["gzip"].encode("utf-8"))
        data = buf.getvalue()
    else:
        data = spec.get("content", "").encode("utf-8")
    return data, spec


def write_tree_file(base: str, path: str, spec, default_mode: int) -> int:
    """Write one file spec under base; returns its size in bytes (0 for links/dirs)."""
    dest = under(base, path)
    if path.endswith("/") or (isinstance(spec, dict) and spec.get("dir")):
        os.makedirs(dest, exist_ok=True)
        if isinstance(spec, dict) and "mode" in spec:
            os.chmod(dest, int(str(spec["mode"]), 8))
        return 0
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    data, opts = file_bytes(spec)
    if os.path.lexists(dest):
        if os.path.isdir(dest) and not os.path.islink(dest):
            shutil.rmtree(dest)
        else:
            os.unlink(dest)
    if data is None:
        os.symlink(opts["symlink"], dest)
        return 0
    with open(dest, "wb") as f:
        f.write(data)
    os.chmod(dest, int(str(opts.get("mode", oct(default_mode)[2:])), 8))
    return len(data)


def deb_basename(name, version, arch):
    return f"{name}_{version.split(':', 1)[-1]}_{arch}.deb"


def pool_dir(component, source):
    prefix = source[:4] if source.startswith("lib") and len(source) > 3 else source[:1]
    return f"pool/{component}/{prefix}/{source}"


def format_description(text: str) -> str:
    lines = text.rstrip("\n").split("\n")
    out = lines[0]
    for line in lines[1:]:
        out += "\n " + (line if line.strip() else ".")
    return out


def control_text(fields: dict) -> str:
    keys = [k for k in CONTROL_ORDER if k in fields] + [k for k in fields if k not in CONTROL_ORDER]
    out = []
    for k in keys:
        v = str(fields[k])
        out.append(f"{k}: {v}" if v else f"{k}:")
    return "\n".join(out) + "\n"


# ─── packages ───────────────────────────────────────────────────────────────

class Package:
    def __init__(self, spec: dict, arch: str, component: str):
        if "name" not in spec or "version" not in spec:
            raise FixtureError(f"package needs name and version: {spec}")
        self.spec = spec
        self.name = spec["name"]
        self.version = str(spec["version"])
        a = spec.get("arch", spec.get("architecture", "native"))
        self.arch = arch if a in ("native", None) else a
        self.component = spec.get("component", component)
        self.source = spec.get("source", self.name).split(" ")[0]
        self.files = spec.get("files")
        if self.files is None:
            self.files = {f"/usr/share/doc/{self.name}/copyright":
                          f"This is the copyright file of the {self.name} package.\n"}
        self.deb_path = None
        self.deb_size = 0
        self.fields = None

    def key(self):
        return (self.name, self.version, self.arch)

    def conffiles(self):
        out = []
        for path, spec in self.files.items():
            if path.endswith("/") or (isinstance(spec, dict) and (spec.get("dir") or "symlink" in spec)):
                continue
            flag = spec.get("conffile") if isinstance(spec, dict) else None
            if flag or (flag is None and path.startswith("/etc/")):
                out.append(path)
        return sorted(out)

    def compute_fields(self) -> dict:
        """The control fields (Installed-Size from the file specs unless given)."""
        size_kib = 0
        for path, spec in self.files.items():
            data, _ = file_bytes(spec) if not path.endswith("/") else (None, {})
            size_kib += (len(data) + 1023) // 1024 if data is not None else 0
        fields = {"Package": self.name, "Version": self.version, "Architecture": self.arch,
                  "Maintainer": self.spec.get("maintainer", DEFAULT_MAINTAINER),
                  "Installed-Size": str(self.spec.get("installed_size", max(size_kib, 1)))}
        for k, field in SPEC_FIELDS.items():
            if k in self.spec and k != "maintainer":
                fields[field] = self.spec[k]
        fields.setdefault("Section", "misc")
        fields.setdefault("Priority", "optional")
        fields.update(self.spec.get("fields", {}))
        fields["Description"] = format_description(self.spec.get("description", f"{self.name} package"))
        self.fields = fields
        return fields

    def build(self, outdir: str, tmp: str) -> str:
        """Build the .deb with dpkg-deb; returns its path."""
        fields = self.compute_fields()
        tree = tempfile.mkdtemp(dir=tmp)
        md5 = []
        conffiles = set(self.conffiles())
        for path, spec in sorted(self.files.items()):
            mode = 0o755 if re.match(r"^/(usr/)?(s?bin|lib/[^/]+/bin)/", path) else 0o644
            write_tree_file(tree, path, spec, mode)
            real = under(tree, path)
            if os.path.isfile(real) and not os.path.islink(real) and path not in conffiles:
                with open(real, "rb") as f:
                    md5.append(f"{hashlib.md5(f.read()).hexdigest()}  {path.lstrip('/')}")
        os.chmod(tree, 0o755)
        debian = os.path.join(tree, "DEBIAN")
        os.makedirs(debian, exist_ok=True)
        with open(os.path.join(debian, "control"), "w", encoding="utf-8") as f:
            f.write(control_text(fields))
        if conffiles:
            with open(os.path.join(debian, "conffiles"), "w") as f:
                f.write("".join(c + "\n" for c in sorted(conffiles)))
        if md5:
            with open(os.path.join(debian, "md5sums"), "w") as f:
                f.write("\n".join(md5) + "\n")
        for script, body in self.spec.get("scripts", {}).items():
            p = os.path.join(debian, script)
            with open(p, "w") as f:
                f.write(body)
            os.chmod(p, 0o755)
        os.makedirs(outdir, exist_ok=True)
        out = os.path.join(outdir, deb_basename(self.name, self.version, self.arch))
        r = run([REAL["dpkg-deb"], "--root-owner-group", "-Zgzip", "--build", tree, out])
        if r.returncode:
            raise FixtureError(f"dpkg-deb failed for {self.name} {self.version}:\n{r.stderr}")
        shutil.rmtree(tree, ignore_errors=True)
        self.deb_path = out
        self.deb_size = os.path.getsize(out)
        return out

    def index_stanza(self, filename: str) -> str:
        """The Packages stanza (control fields + Filename/Size/hashes, dpkg-scanpackages order)."""
        f = dict(self.fields)
        desc = f.pop("Description")
        extra = {}
        if self.deb_path:
            with open(self.deb_path, "rb") as fh:
                data = fh.read()
            extra = {"Filename": filename, "Size": str(len(data)),
                     "MD5sum": hashlib.md5(data).hexdigest(),
                     "SHA1": hashlib.sha1(data).hexdigest(),
                     "SHA256": hashlib.sha256(data).hexdigest()}
        else:
            fake = hashlib.sha256(control_text(self.fields).encode()).hexdigest()
            extra = {"Filename": filename, "Size": str(int(f.get("Installed-Size", "1")) * 400 + 1200),
                     "MD5sum": fake[:32], "SHA1": fake[:40], "SHA256": fake}
        order = ["Package", "Source", "Version", "Architecture", "Maintainer", "Installed-Size",
                 "Pre-Depends", "Depends", "Recommends", "Suggests", "Enhances", "Conflicts", "Breaks",
                 "Replaces", "Provides", "Filename", "Size", "MD5sum", "SHA1", "SHA256", "Section",
                 "Priority", "Multi-Arch", "Essential", "Homepage"]
        f.update(extra)
        keys = [k for k in order if k in f] + [k for k in f if k not in order]
        return "".join(f"{k}: {f[k]}\n" for k in keys) + f"Description: {desc}\n"


# ─── repositories ───────────────────────────────────────────────────────────

class Repo:
    def __init__(self, spec: dict, sandbox: str, arch: str, date: dt.datetime):
        self.spec = spec
        self.name = spec.get("name") or spec.get("suite") or "main"
        self.path = os.path.join(sandbox, spec.get("path", f"repos/{self.name}"))
        self.suite = spec.get("suite", "stable")
        self.codename = spec.get("codename", self.suite)
        self.components = spec.get("components", ["main"])
        self.arch = arch
        self.date = date
        self.debs = spec.get("debs", True)
        self.packages = [Package(p, arch, self.components[0]) for p in spec.get("packages", [])]
        seen = set()
        for p in self.packages:
            if p.key() in seen:
                raise FixtureError(f"repo {self.name}: {p.name} {p.version} {p.arch} listed twice")
            seen.add(p.key())
            if p.component not in self.components:
                raise FixtureError(f"repo {self.name}: {p.name} uses component {p.component!r} "
                                   f"not in {self.components}")

    def build(self, tmp: str):
        if os.path.isdir(os.path.join(self.path, "dists")):
            shutil.rmtree(os.path.join(self.path, "dists"))
        if os.path.isdir(os.path.join(self.path, "pool")):
            shutil.rmtree(os.path.join(self.path, "pool"))
        stanzas = {c: [] for c in self.components}
        for p in sorted(self.packages, key=lambda p: (p.name, p.version)):
            rel = f"{pool_dir(p.component, p.source)}/{deb_basename(p.name, p.version, p.arch)}"
            if self.debs:
                p.build(os.path.dirname(os.path.join(self.path, rel)), tmp)
            else:
                p.compute_fields()             # index only, no .deb file
            stanzas[p.component].append(p.index_stanza(rel))
        dist = os.path.join(self.path, "dists", self.suite)
        index_files = []
        for comp in self.components:
            d = os.path.join(dist, comp, f"binary-{self.arch}")
            os.makedirs(d, exist_ok=True)
            text = "\n".join(stanzas[comp]).encode("utf-8")
            with open(os.path.join(d, "Packages"), "wb") as f:
                f.write(text)
            with open(os.path.join(d, "Packages.gz"), "wb") as raw, \
                    gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as f:
                f.write(text)
            with open(os.path.join(d, "Release"), "w") as f:
                f.write(f"Archive: {self.suite}\nOrigin: {self.spec.get('origin', 'LinuxMissions')}\n"
                        f"Label: {self.spec.get('label', self.spec.get('origin', 'LinuxMissions'))}\n"
                        f"Component: {comp}\nArchitecture: {self.arch}\n")
            for fn in ("Packages", "Packages.gz", "Release"):
                index_files.append(f"{comp}/binary-{self.arch}/{fn}")
        lines = [f"Origin: {self.spec.get('origin', 'LinuxMissions')}",
                 f"Label: {self.spec.get('label', self.spec.get('origin', 'LinuxMissions'))}",
                 f"Suite: {self.suite}"]
        if "version" in self.spec:
            lines.append(f"Version: {self.spec['version']}")
        lines.append(f"Codename: {self.codename}")
        lines.append(f"Date: {self.date.strftime('%a, %d %b %Y %H:%M:%S UTC')}")
        if self.spec.get("not_automatic"):
            lines.append("NotAutomatic: yes")
        if self.spec.get("but_automatic_upgrades"):
            lines.append("ButAutomaticUpgrades: yes")
        lines.append(f"Architectures: {self.arch}")
        lines.append(f"Components: {' '.join(self.components)}")
        lines.append(f"Description: {self.spec.get('description', self.spec.get('origin', 'LinuxMissions') + ' ' + self.suite)}")
        for algo, name in (("md5", "MD5Sum"), ("sha256", "SHA256")):
            lines.append(f"{name}:")
            for rel in index_files:
                with open(os.path.join(dist, rel), "rb") as f:
                    data = f.read()
                lines.append(f" {hashlib.new(algo, data).hexdigest()} {len(data):>16} {rel}")
        release = "\n".join(lines) + "\n"
        with open(os.path.join(dist, "Release"), "w") as f:
            f.write(release)
        key = self.spec.get("sign")
        if key:
            import pgp
            k = pgp.load_key(key)
            when = int(self.spec.get("sign_time", self.date.replace(tzinfo=dt.timezone.utc).timestamp()))
            with open(os.path.join(dist, "InRelease"), "w") as f:
                f.write(pgp.clearsign(k, release, when))
            with open(os.path.join(dist, "Release.gpg"), "wb") as f:
                f.write(pgp.detach_sign(k, release.encode(), True, when))

    def sources_entry(self, root: str, fmt: str) -> str:
        uri = f"{self.spec.get('uri_scheme', 'file')}:{os.path.abspath(self.path)}"
        signed_by = self.signed_by(root)
        trusted = self.spec.get("trusted", not self.spec.get("sign"))
        if fmt == "deb822":
            out = [f"Types: deb", f"URIs: {uri}", f"Suites: {self.suite}",
                   f"Components: {' '.join(self.components)}"]
            if signed_by:
                out.append(f"Signed-By: {signed_by}")
            if trusted:
                out.append("Trusted: yes")
            return "\n".join(out) + "\n"
        opts = []
        if signed_by:
            opts.append(f"signed-by={signed_by}")
        if trusted:
            opts.append("trusted=yes")
        o = f" [{' '.join(opts)}]" if opts else ""
        return f"deb{o} {uri} {self.suite} {' '.join(self.components)}\n"

    def signed_by(self, root):
        if "signed_by" in self.spec:
            sb = self.spec["signed_by"]
            return under(root, sb) if sb else None
        if self.spec.get("sign"):
            return under(root, f"/etc/apt/keyrings/{self.name}.gpg")
        return None


# ─── the world ──────────────────────────────────────────────────────────────

def apt_conf(root: str, arch: str) -> str:
    return f"""// LinuxMissions sandbox: apt and dpkg work on this directory tree instead of /.
// Written by mocks/packages/pkgsim.py; the tools in the sandbox's bin/ read it
// through APT_CONFIG. This is not a normal apt.conf: don't copy it to a server.
Dir "{root}/";
Dir::State "var/lib/apt/";
Dir::State::status "{root}/var/lib/dpkg/status";
Dir::Cache "var/cache/apt/";
Dir::Etc "etc/apt/";
Dir::Log "var/log/apt/";
Dir::Bin::dpkg "/usr/bin/dpkg";
Debug::NoLocking "true";
APT::Architecture "{arch}";
#clear APT::Architectures;
APT::Architectures {{ "{arch}"; }};
Acquire::Languages "none";
#clear DPkg::Options;
DPkg::Options {{ "--root={root}"; "--force-not-root"; "--force-bad-path"; "--force-script-chrootless"; "--path-include=/*"; "--log={root}/var/log/dpkg.log"; }};
"""


def history_text(entries) -> str:
    out = []
    for e in entries:
        start = e["start"]
        block = ["", f"Start-Date: {start[:10]}  {start[11:19]}" if len(start) > 10 else f"Start-Date: {start}"]
        if e.get("commandline"):
            block.append(f"Commandline: {e['commandline']}")
        if e.get("requested_by"):
            block.append(f"Requested-By: {e['requested_by']}")
        for key, label in (("install", "Install"), ("reinstall", "Reinstall"), ("upgrade", "Upgrade"),
                           ("downgrade", "Downgrade"), ("remove", "Remove"), ("purge", "Purge")):
            if e.get(key):
                val = e[key]
                block.append(f"{label}: {val if isinstance(val, str) else ', '.join(val)}")
        if e.get("error"):
            block.append(f"Error: {e['error']}")
        end = e.get("end", start)
        block.append(f"End-Date: {end[:10]}  {end[11:19]}" if len(end) > 10 else f"End-Date: {end}")
        out.append("\n".join(block) + "\n")
    return "".join(out)


def dpkg_cmd(root, *args, log="/dev/null"):
    return [REAL["dpkg"], f"--root={root}", "--force-not-root", "--force-bad-path",
            "--force-script-chrootless", "--path-include=/*", f"--log={log}", *args]


def wrapper_text(tool: str, root: str, lib: str) -> str:
    q = lambda s: "'" + s.replace("'", "'\\''") + "'"  # noqa: E731
    head = (f"#!/bin/sh\n# LinuxMissions sandbox {tool}: the real {tool}, working on the package world\n"
            f"# under {root} (see mocks/README.md, \"packages\").\n")
    conf = f"APT_CONFIG={q(root + '/etc/apt/apt.conf')}; export APT_CONFIG\n"
    if tool in ("apt", "apt-get"):
        return head + conf + f"exec python3 {q(lib + '/pkgsim.py')} --wrap {tool} {q(root)} \"$@\"\n"
    if tool == "dpkg":
        return head + conf + (f"exec {REAL['dpkg']} --root={q(root)} --force-not-root --force-bad-path "
                              f"--force-script-chrootless --path-include='/*' --log={q(root + '/var/log/dpkg.log')} \"$@\"\n")
    if tool == "dpkg-query":
        return head + f"exec {REAL['dpkg-query']} --root={q(root)} \"$@\"\n"
    return head + conf + f"exec {REAL[tool]} \"$@\"\n"


def build(sandbox: str, fixture: dict, update=True, repos_only=False):
    if not shutil.which(REAL["dpkg-deb"]) and not os.path.exists(REAL["dpkg-deb"]):
        raise FixtureError("pkgsim needs dpkg, dpkg-deb and apt (Debian/Ubuntu only)")
    sandbox = os.path.abspath(sandbox)
    root = os.path.join(sandbox, fixture.get("root", "rootfs"))
    arch = fixture.get("arch", "native")
    arch = native_arch() if arch in (None, "native") else arch
    date = dt.datetime.strptime(fixture.get("date", "2024-04-01 12:00:00"), "%Y-%m-%d %H:%M:%S")
    tmp = tempfile.mkdtemp(prefix="pkgsim.")
    try:
        repos = [Repo(r, sandbox, arch, date) for r in fixture.get("repos", [])]
        names = [r.name for r in repos]
        if len(set(names)) != len(names):
            raise FixtureError(f"repo names must be unique: {names}")
        for r in repos:
            r.build(tmp)
        if repos_only:
            if update and fixture.get("update", True):
                apt_update(root, fixture.get("update", True))
            return root

        for d in ("etc/apt/apt.conf.d", "etc/apt/preferences.d", "etc/apt/sources.list.d",
                  "etc/apt/trusted.gpg.d", "etc/apt/keyrings", "etc/apt/auth.conf.d",
                  "var/lib/apt/lists/partial", "var/lib/apt/periodic", "var/cache/apt/archives/partial",
                  "var/log/apt", "var/lib/dpkg/info", "var/lib/dpkg/updates", "var/lib/dpkg/triggers",
                  "var/lib/dpkg/alternatives", "usr/share/keyrings"):
            os.makedirs(os.path.join(root, d), exist_ok=True)
        for f in ("var/lib/dpkg/status", "var/lib/dpkg/available", "var/log/dpkg.log",
                  "var/log/apt/history.log", "var/log/apt/term.log"):
            p = os.path.join(root, f)
            if not os.path.exists(p):
                open(p, "w").close()
        with open(os.path.join(root, "etc/apt/apt.conf"), "w") as f:
            f.write(apt_conf(root, arch))
        for link, target in fixture.get("links", {}).items():
            dest = under(root, link)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            if not os.path.lexists(dest):
                os.symlink(target, dest)

        # keyrings
        import pgp
        keyrings = dict(fixture.get("keyrings", {}))
        for r in repos:
            sb = r.signed_by(root)
            if r.spec.get("sign") and sb and "signed_by" not in r.spec:
                keyrings.setdefault(f"/etc/apt/keyrings/{r.name}.gpg", {"key": r.spec["sign"]})
        for path, spec in keyrings.items():
            keys = spec if isinstance(spec, list) else [spec]
            data = b""
            for k in keys:
                if isinstance(k, str):
                    k = {"key": k}
                data += pgp.export_public(pgp.load_key(k["key"]), k.get("uid"))
            dest = under(root, path)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            armor = path.endswith(".asc") or any(isinstance(k, dict) and k.get("armor") for k in keys)
            with open(dest, "wb") as f:
                f.write(pgp.armor_block(data, "PUBLIC KEY BLOCK").encode() if armor else data)

        # sources
        main_list = []
        for r in repos:
            fmt = r.spec.get("sources", "list")
            if fmt == "none":
                continue
            if fmt == "main":
                main_list.append(r.sources_entry(root, "list"))
                continue
            ext = ".sources" if fmt == "deb822" else ".list"
            name = r.spec.get("sources_file", r.name + ext)
            with open(os.path.join(root, "etc/apt/sources.list.d", name), "w") as f:
                f.write(r.sources_entry(root, fmt))
        if main_list or not os.path.exists(os.path.join(root, "etc/apt/sources.list")):
            with open(os.path.join(root, "etc/apt/sources.list"), "w") as f:
                f.write("".join(main_list))

        # installed packages
        install_debs, unpack_debs, remove_after, states, autos = [], [], [], {}, []
        installed = list(fixture.get("installed", []))
        if fixture.get("base_files", True) and not any(
                (s if isinstance(s, str) else s.get("name")) == "base-files" for s in installed):
            # Owns the standard directories, as on a real system, so removing a
            # fixture package does not try to rmdir /etc or /usr/bin.
            links = set(fixture.get("links", {}))
            installed.insert(0, {"name": "base-files", "version": "13ubuntu10", "local": True,
                                 "section": "admin", "priority": "required", "essential": "yes",
                                 "description": "Debian base system miscellaneous files\n"
                                                "This package contains the basic filesystem hierarchy.",
                                 "files": {d + "/": {"dir": True} for d in BASE_DIRS
                                           if not any(d == l or d.startswith(l + "/") for l in links)}})
        for spec in installed:
            if isinstance(spec, str):
                spec = {"name": spec}
            name = spec["name"]
            state = spec.get("state", "ii")
            local = spec.get("local") or "files" in spec or "description" in spec
            if local:
                pkg = Package(spec, arch, "main")
                pkg.build(os.path.join(root, "var/cache/apt/archives"), tmp)
            else:
                version = spec.get("version")
                cands = [p for r in repos for p in r.packages if p.name == name
                         and (version is None or p.version == str(version))]
                if not cands:
                    raise FixtureError(f"installed: {name} {version or ''} is in no repo; "
                                       "give its files/description and \"local\": true")
                if version is None:
                    vs = sorted({p.version for p in cands}, key=_VersionKey)
                    cands = [p for p in cands if p.version == vs[-1]]
                pkg = cands[0]
                if not pkg.deb_path:
                    pkg.build(os.path.join(tmp, "debs"), tmp)
            if not re.fullmatch(r"[uihrp][ncHUFWti]R?", state):
                raise FixtureError(f"installed: {name}: bad state {state!r} (like ii, rc, iU, hi, iF)")
            if state[1] in ("U", "H"):
                unpack_debs.append(pkg.deb_path)
            elif state[1] != "n":
                install_debs.append(pkg.deb_path)
            if state[1] == "c":
                remove_after.append(name)
            states[name] = state
            if spec.get("auto"):
                autos.append(name)
        if install_debs:
            _dpkg_or_die(root, "--force-depends", "--force-conflicts", "--force-confdef",
                         "--force-confold", "-i", *install_debs)
        if unpack_debs:
            _dpkg_or_die(root, "--force-depends", "--force-conflicts", "--unpack", *unpack_debs)
        if remove_after:
            _dpkg_or_die(root, "--force-depends", "-r", *remove_after)
        _patch_status(root, states)
        if autos:
            with open(os.path.join(root, "var/lib/apt/extended_states"), "a") as f:
                for name in autos:
                    pa = _status_arch(root, name) or arch
                    f.write(f"Package: {name}\nArchitecture: {pa}\nAuto-Installed: 1\n\n")

        # history, extra files
        hist = fixture.get("history")
        if hist:
            with open(os.path.join(root, "var/log/apt/history.log"), "a") as f:
                f.write(history_text(hist))
        for path, spec in fixture.get("files", {}).items():
            write_tree_file(root, path, spec, 0o644)
        for path in fixture.get("remove_files", []):
            p = under(root, path)
            if os.path.isdir(p) and not os.path.islink(p):
                shutil.rmtree(p)
            elif os.path.lexists(p):
                os.unlink(p)

        # wrappers
        bindir = os.path.join(sandbox, fixture.get("bin", "bin"))
        lib = os.path.join(bindir, ".mocks", "packages")
        os.makedirs(lib, exist_ok=True)
        shutil.copy2(os.path.join(HERE, "pkgsim.py"), os.path.join(lib, "pkgsim.py"))
        for tool in WRAPPED:
            p = os.path.join(bindir, tool)
            with open(p, "w") as f:
                f.write(wrapper_text(tool, root, lib))
            os.chmod(p, 0o755)

        if update and fixture.get("update", True):
            apt_update(root, fixture.get("update", True))
        return root
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def apt_update(root, mode=True):
    env = dict(os.environ, APT_CONFIG=os.path.join(root, "etc/apt/apt.conf"))
    r = run([REAL["apt-get"], "update", "-q"], env=env)
    bad = r.returncode != 0 or re.search(r"^(W|E|Err):", r.stdout + r.stderr, re.M)
    if bad and mode != "try":
        raise FixtureError("apt-get update failed in the sandbox (set \"update\": \"try\" or false "
                           f"if that is intended):\n{r.stdout}{r.stderr}")


def _dpkg_or_die(root, *args):
    r = run(dpkg_cmd(root, *args))
    if r.returncode:
        raise FixtureError(f"dpkg {' '.join(args[:3])} ... failed:\n{r.stdout}{r.stderr}")


def _read_status(root):
    with open(os.path.join(root, "var/lib/dpkg/status"), encoding="utf-8") as f:
        return f.read()


def _status_arch(root, name):
    m = re.search(rf"^Package: {re.escape(name)}\n(?:[^\n]+\n)*?Architecture: (\S+)", _read_status(root), re.M)
    return m.group(1) if m else None


def _patch_status(root, states):
    text = _read_status(root)
    stanzas = text.split("\n\n")
    out = []
    for st in stanzas:
        m = re.match(r"Package: (\S+)", st)
        if m and m.group(1) in states:
            s = states[m.group(1)]
            want, cur = WANT[s[0]], STATE[s[1]]
            err = "reinstreq" if s[2:] == "R" else "ok"
            st = re.sub(r"^Status: .*$", f"Status: {want} {err} {cur}", st, count=1, flags=re.M)
        out.append(st)
    with open(os.path.join(root, "var/lib/dpkg/status"), "w", encoding="utf-8") as f:
        f.write("\n\n".join(out))


class _VersionKey:
    """Sort key using dpkg --compare-versions (only for picking the newest fixture version)."""

    def __init__(self, v):
        self.v = v

    def __lt__(self, other):
        return run([REAL["dpkg"], "--compare-versions", self.v, "lt", other.v]).returncode == 0


# ─── apt / apt-get wrapper ──────────────────────────────────────────────────

MODIFYING = {"install", "remove", "purge", "upgrade", "full-upgrade", "dist-upgrade", "dselect-upgrade",
             "autoremove", "autopurge", "auto-remove", "reinstall", "satisfy", "build-dep"}
SIMULATE = {"-s", "--simulate", "--just-print", "--dry-run", "--recon", "--no-act"}
VALUE_OPTS = {"-o", "--option", "-c", "--config-file", "-t", "--target-release", "--default-release",
              "-a", "--host-architecture", "-P", "--build-profiles"}
DONE_LINES = ("Reading package lists...", "Building dependency tree...", "Reading state information...",
              "Calculating upgrade...")


def wrap_apt(tool: str, root: str, argv) -> int:
    env = dict(os.environ, APT_CONFIG=os.path.join(root, "etc/apt/apt.conf"))
    action, simulate, i = None, False, 0
    while i < len(argv):
        a = argv[i]
        if a in VALUE_OPTS:
            if i + 1 < len(argv) and re.match(r"(?i)apt::get::(simulate|trivial-only)=(1|true|yes)", argv[i + 1]):
                simulate = True
            i += 2
            continue
        if a in SIMULATE or (a.startswith("-") and not a.startswith("--") and "s" in a[1:] and a[1:].isalpha()):
            simulate = True
        elif not a.startswith("-") and action is None:
            action = a
        i += 1
    real = REAL[tool]
    if action not in MODIFYING or simulate or not sys.stdout.isatty():
        os.execve(real, [tool] + list(argv), env)
    # Interactive: apt's own prompt cannot be answered from the game's shell, so
    # read its output, add what a terminal shows, and answer the question.
    answer = os.environ.get("LM_APT_ANSWER", "Y")
    # apt would warn "does not have a stable CLI interface" because its output is
    # now a pipe; switch that off in a config layered over the sandbox one (an -o
    # option would show up in history.log's Commandline).
    fd, conf = tempfile.mkstemp(prefix="lm-apt.", suffix=".conf")
    with os.fdopen(fd, "w") as f:
        f.write(f'#include "{env["APT_CONFIG"]}";\nApt::Cmd::Disable-Script-Warning "true";\n')
    env["APT_CONFIG"] = conf
    try:
        return _run_answering(tool, real, argv, env, answer)
    finally:
        os.unlink(conf)


def _run_answering(tool, real, argv, env, answer) -> int:
    proc = subprocess.Popen([tool] + list(argv), executable=real, env=env, stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE)
    out = sys.stdout.buffer
    buf = b""
    answered = False
    while True:
        chunk = os.read(proc.stdout.fileno(), 4096)
        if not chunk:
            break
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            text = line.decode("utf-8", "replace")
            if text in DONE_LINES:
                line += b" Done"
            out.write(line + b"\n")
        if re.search(rb"\[[Yy]/[Nn]\] $", buf) and not answered:
            out.write(buf + answer.encode() + b"\n")
            buf = b""
            out.flush()
            try:
                proc.stdin.write(answer.encode() + b"\n")
                proc.stdin.flush()
            except BrokenPipeError:
                pass
            answered = True
        out.flush()
    if buf:
        out.write(buf)
        out.flush()
    try:
        proc.stdin.close()
    except BrokenPipeError:
        pass
    return proc.wait()


def main(argv) -> int:
    if len(argv) >= 3 and argv[0] == "--wrap":
        return wrap_apt(argv[1], argv[2], argv[3:])
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "build":
        args = [a for a in argv[1:] if not a.startswith("--")]
        flags = {a for a in argv[1:] if a.startswith("--")}
        if len(args) != 2:
            print("usage: pkgsim.py build SANDBOX FIXTURE.json [--no-update] [--repos-only]", file=sys.stderr)
            return 2
        with open(args[1], encoding="utf-8") if args[1] != "-" else sys.stdin as f:
            fixture = json.load(f)
        try:
            build(args[0], fixture, update="--no-update" not in flags, repos_only="--repos-only" in flags)
        except FixtureError as exc:
            print(f"pkgsim: {exc}", file=sys.stderr)
            return 1
        return 0
    if argv[0] == "sign-file" and len(argv) == 3:
        import pgp
        with open(argv[2], encoding="utf-8") as f:
            sys.stdout.write(pgp.clearsign(pgp.load_key(argv[1]), f.read()))
        return 0
    print(f"pkgsim: unknown command {argv[0]}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
