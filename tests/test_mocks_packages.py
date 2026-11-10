"""Unit tests for the package-world mock in mocks/packages/ (pkgsim.py, pgp.py).

Run: python3 -m unittest tests.test_mocks_packages -v   (or scripts/test-levels-docker.sh --unit)
The package world drives the real apt and dpkg, so those tests need Debian or
Ubuntu (the reference image); elsewhere they are skipped. The signing tests
need only gpgv.
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PKG = REPO / "mocks" / "packages"
sys.path.insert(0, str(PKG))

import pgp  # noqa: E402

HAVE_DEBIAN = (platform.system() == "Linux" and os.path.exists("/usr/bin/dpkg-deb")
               and os.path.exists("/usr/bin/apt-get"))
SKIP_REASON = "needs Debian/Ubuntu tooling (dpkg, dpkg-deb, apt); run in the reference image"
GPGV = shutil.which("gpgv")


class PgpTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="lm-pgp."))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_keys(self):
        self.assertEqual(pgp.available_keys(), ["key1", "key2", "key3", "key4"])
        k = pgp.load_key("key2")
        self.assertEqual(k.fingerprint, "3493CB32905056D759665382AD8E476A51178E68")
        self.assertEqual(k.keyid, "AD8E476A51178E68")
        self.assertEqual(k.n.bit_length(), 3072)
        armored = pgp.export_public(k, "A <a@example.org>", armor=True).decode()
        self.assertTrue(armored.startswith("-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n"))
        self.assertRegex(armored, r"\n=[A-Za-z0-9+/]{4}\n-----END PGP PUBLIC KEY BLOCK-----\n$")

    def test_clearsign_format(self):
        text = pgp.clearsign(pgp.load_key("key1"), "Origin: X\n-dash\n", when=1700000000)
        self.assertTrue(text.startswith("-----BEGIN PGP SIGNED MESSAGE-----\nHash: SHA512\n\nOrigin: X\n- -dash\n"
                                        "-----BEGIN PGP SIGNATURE-----\n"))

    @unittest.skipUnless(GPGV, "needs gpgv")
    def test_gpgv_accepts_signatures(self):
        release = "Origin: Vendor\nSuite: stable\n-odd line\ntrailing blanks   \n"
        (self.tmp / "Release").write_text(release)
        (self.tmp / "good.gpg").write_bytes(pgp.export_public(pgp.load_key("key3"), "Vendor <v@example.org>"))
        (self.tmp / "other.gpg").write_bytes(pgp.export_public(pgp.load_key("key4")))
        (self.tmp / "InRelease").write_text(pgp.clearsign(pgp.load_key("key3"), release, when=1712000000))
        (self.tmp / "Release.gpg").write_bytes(pgp.detach_sign(pgp.load_key("key3"), release.encode(), True, 1712000000))
        (self.tmp / "Release.sig").write_bytes(pgp.detach_sign(pgp.load_key("key3"), release.encode(), False, 1712000000))

        def gpgv(keyring, *files):
            return subprocess.run([GPGV, "--keyring", str(self.tmp / keyring), *map(str, files)],
                                  capture_output=True, text=True)
        for sig in (["InRelease"], ["Release.gpg", "Release"], ["Release.sig", "Release"]):
            r = gpgv("good.gpg", *[self.tmp / s for s in sig])
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('Good signature from "Vendor <v@example.org>"', r.stderr)
        r = gpgv("other.gpg", self.tmp / "InRelease")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("No public key", r.stderr)
        (self.tmp / "Release").write_text(release + "tampered\n")
        self.assertNotEqual(gpgv("good.gpg", self.tmp / "Release.gpg", self.tmp / "Release").returncode, 0)

    def test_cli(self):
        r = subprocess.run([sys.executable, str(PKG / "pgp.py"), "fingerprint", "key4"], capture_output=True, text=True)
        self.assertEqual(r.stdout.strip(), "8486E7EA36711750B9BB6C4AB9FF70DC34EB2F85")


FIXTURE = {
    "date": "2024-04-01 12:00:00",
    "links": {"/bin": "usr/bin"},
    "repos": [
        {"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "label": "Ubuntu", "version": "24.04",
         "components": ["main", "universe"], "sources": "deb822", "sign": "key3",
         "packages": [
             {"name": "fluxd", "version": "3.2.0-1", "depends": "libflux1 (>= 1.5)", "section": "net",
              "description": "Flux streaming daemon\nStreams flux.\n\nSecond paragraph.",
              "files": {"/usr/bin/fluxd": "#!/bin/sh\necho fluxd 3.2.0\n", "/etc/fluxd/fluxd.conf": "port=1\n"}},
             {"name": "fluxd", "version": "3.1.4-1", "depends": "libflux1 (>= 1.4), libflux1 (<< 1.5)",
              "section": "net",
              "files": {"/usr/bin/fluxd": "#!/bin/sh\necho fluxd 3.1.4\n", "/etc/fluxd/fluxd.conf": "port=1\n"}},
             {"name": "libflux1", "version": "1.5.0-1", "section": "libs"},
             {"name": "libflux1", "version": "1.4.2-1", "section": "libs"},
             {"name": "oldmon", "version": "1.0-1", "component": "universe",
              "files": {"/etc/oldmon/oldmon.conf": "x=1\n", "/usr/bin/oldmon": "#!/bin/sh\n"}},
             {"name": "tool", "version": "2.0-1", "files": {"/usr/bin/tool": "#!/bin/sh\necho tool\n"}},
             {"name": "notes", "version": "1.0-1", "files": {
                 "/usr/share/doc/notes/changelog.Debian.gz": {"gzip": "notes (1.0-1) noble; urgency=medium\n"},
                 "/usr/share/man/man1/notes.1": "manual\n"}},
         ]},
        {"name": "backports", "suite": "noble-backports", "origin": "Ubuntu", "not_automatic": True,
         "but_automatic_upgrades": True,
         "packages": [{"name": "ripgrep", "version": "14.1.0-1~bpo1"}, {"name": "tool", "version": "2.1-1~bpo1"}]},
    ],
    "installed": [
        {"name": "libflux1", "version": "1.5.0-1", "auto": True},
        {"name": "oldmon", "state": "rc"},
        {"name": "tool", "version": "2.0-1", "state": "hi"},
        {"name": "notes"},
        {"name": "legacy-agent", "version": "0.9", "local": True, "state": "iF", "description": "Old agent",
         "files": {"/opt/legacy/agent": "bin"}},
    ],
    "history": [{"start": "2024-03-01 10:00:00", "end": "2024-03-01 10:00:04",
                 "commandline": "apt-get install oldmon", "install": ["oldmon:amd64 (1.0-1)"]}],
    "files": {"/etc/apt/preferences.d/10-ripgrep.pref":
              "Package: ripgrep\nPin: release a=noble-backports\nPin-Priority: 500\n"},
}


@unittest.skipUnless(HAVE_DEBIAN, SKIP_REASON)
class PackageWorldTests(unittest.TestCase):
    def make(self, fixture=FIXTURE, *flags, check=True):
        sb = Path(tempfile.mkdtemp(prefix="lm-pkg-sb."))
        self.addCleanup(shutil.rmtree, sb, True)
        fx = sb.parent / (sb.name + ".json")
        fx.write_text(json.dumps(fixture))
        self.addCleanup(fx.unlink)
        r = subprocess.run([sys.executable, str(PKG / "pkgsim.py"), "build", str(sb), str(fx), *flags],
                           capture_output=True, text=True)
        if check:
            self.assertEqual(r.returncode, 0, r.stderr)
        self.sb = sb
        return sb, r

    def sh(self, cmd, env=None, check=False):
        e = dict(os.environ, PATH=f"{self.sb}/bin:{os.environ['PATH']}")
        e.pop("APT_CONFIG", None)
        e.update(env or {})
        r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, cwd=str(self.sb), env=e, timeout=120)
        if check:
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r

    def status(self):
        r = self.sh("dpkg-query -W -f='${db:Status-Abbrev}|${Package}|${Version}\\n'", check=True)
        return {p: (s.strip(), v) for s, p, v in (line.split("|") for line in r.stdout.splitlines())}

    def test_layout_and_initial_state(self):
        sb, _ = self.make()
        root = sb / "rootfs"
        for tool in ("apt", "apt-get", "apt-cache", "apt-mark", "apt-config", "apt-key", "dpkg", "dpkg-query"):
            self.assertTrue(os.access(sb / "bin" / tool, os.X_OK), tool)
        self.assertEqual(self.status(), {
            "base-files": ("ii", "13ubuntu10"), "legacy-agent": ("iF", "0.9"), "libflux1": ("ii", "1.5.0-1"),
            "notes": ("ii", "1.0-1"), "oldmon": ("rc", "1.0-1"), "tool": ("hi", "2.0-1")})
        src = (root / "etc/apt/sources.list.d/ubuntu.sources").read_text()
        self.assertEqual(src, f"Types: deb\nURIs: file:{sb}/repos/ubuntu\nSuites: noble\nComponents: main universe\n"
                              f"Signed-By: {root}/etc/apt/keyrings/ubuntu.gpg\n")
        self.assertIn("trusted=yes", (root / "etc/apt/sources.list.d/backports.list").read_text())
        release = (sb / "repos/ubuntu/dists/noble/Release").read_text()
        self.assertIn("Origin: Ubuntu\nLabel: Ubuntu\nSuite: noble\nVersion: 24.04\nCodename: noble\n"
                      "Date: Mon, 01 Apr 2024 12:00:00 UTC\n", release)
        self.assertNotIn("Valid-Until", release)
        self.assertIn("NotAutomatic: yes\nButAutomaticUpgrades: yes\n",
                      (sb / "repos/backports/dists/noble-backports/Release").read_text())
        self.assertTrue(list((sb / "repos/ubuntu/pool/main/libf/libflux1").glob("libflux1_1.5.0-1_*.deb")))
        self.assertTrue(any(p.name.endswith("_Packages") for p in (root / "var/lib/apt/lists").iterdir()))
        self.assertIn("Commandline: apt-get install oldmon", (root / "var/log/apt/history.log").read_text())
        self.assertTrue((root / "usr/share/man/man1/notes.1").exists(), "host dpkg path-exclude must not apply")
        self.assertTrue((root / "usr/share/doc/notes/changelog.Debian.gz").exists())
        self.assertTrue((root / "etc/oldmon/oldmon.conf").exists())     # rc keeps conffiles
        self.assertEqual(self.sh("apt-mark showhold").stdout, "tool\n")
        self.assertEqual(self.sh("apt-mark showauto").stdout, "libflux1\n")
        r = self.sh("dpkg -l legacy-agent")
        self.assertRegex(r.stdout, r"\niF  legacy-agent +0\.9 ")

    def test_policy_and_pinning(self):
        self.make()
        r = self.sh("apt-cache policy ripgrep tool fluxd", check=True)
        self.assertRegex(r.stdout, r"ripgrep:\n  Installed: \(none\)\n  Candidate: 14\.1\.0-1~bpo1\n")
        self.assertRegex(r.stdout, r"14\.1\.0-1~bpo1 500\n +100 file:\S+/repos/backports noble-backports/main")
        self.assertRegex(r.stdout, r"tool:\n  Installed: 2\.0-1\n  Candidate: 2\.0-1\n")
        self.assertRegex(r.stdout, r"fluxd:\n  Installed: \(none\)\n  Candidate: 3\.2\.0-1\n")
        r = self.sh("apt-cache madison fluxd", check=True)
        self.assertEqual(len(r.stdout.splitlines()), 2)
        r = self.sh("apt-cache show fluxd=3.2.0-1", check=True)
        self.assertIn("Description: Flux streaming daemon\n Streams flux.\n .\n Second paragraph.\n", r.stdout)
        self.assertIn("Depends: libflux1 (>= 1.5)\n", r.stdout)

    def test_install_remove_purge(self):
        sb, _ = self.make()
        root = sb / "rootfs"
        r = self.sh("apt-get install -y fluxd")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("Setting up fluxd (3.2.0-1) ...", r.stdout)
        self.assertEqual((root / "usr/bin/fluxd").read_text(), "#!/bin/sh\necho fluxd 3.2.0\n")
        self.assertEqual(self.sh("fluxd_bin=rootfs/bin/fluxd; sh $fluxd_bin").stdout, "fluxd 3.2.0\n")
        hist = (root / "var/log/apt/history.log").read_text()
        self.assertRegex(hist, r"Commandline: apt-get install -y fluxd\nInstall: fluxd:\S+ \(3\.2\.0-1\)\n")
        self.assertRegex((root / "var/log/dpkg.log").read_text(), r"status installed fluxd:\S+ 3\.2\.0-1")
        self.assertIn("Unpacking fluxd (3.2.0-1)", (root / "var/log/apt/term.log").read_text())
        r = self.sh("apt-get remove -y fluxd")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("not empty so not removed", r.stdout + r.stderr)
        self.assertEqual(self.status()["fluxd"], ("rc", "3.2.0-1"))
        self.assertFalse((root / "usr/bin/fluxd").exists())
        self.assertTrue((root / "etc/fluxd/fluxd.conf").exists())
        r = self.sh("apt-get purge -y fluxd oldmon")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("not empty so not removed", r.stdout + r.stderr)
        st = self.status()
        self.assertNotIn("fluxd", st)
        self.assertNotIn("oldmon", st)
        self.assertFalse((root / "etc/fluxd").exists())
        self.assertFalse((root / "etc/oldmon").exists())
        self.assertTrue((root / "usr/bin").is_dir())

    def test_pinned_versions_and_downgrade(self):
        self.make()
        r = self.sh("apt-get install -y fluxd=3.1.4-1")
        self.assertEqual(r.returncode, 100)
        self.assertIn("fluxd : Depends: libflux1 (< 1.5) but 1.5.0-1 is to be installed", r.stdout)
        r = self.sh("apt-get install -y fluxd=3.1.4-1 libflux1=1.4.2-1")
        self.assertIn("E: Packages were downgraded and -y was used without --allow-downgrades.", r.stderr)
        r = self.sh("apt-get install -y --allow-downgrades fluxd=3.1.4-1 libflux1=1.4.2-1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        st = self.status()
        self.assertEqual((st["fluxd"], st["libflux1"]), (("ii", "3.1.4-1"), ("ii", "1.4.2-1")))

    def test_holds_and_upgrade_plan(self):
        sb, _ = self.make()
        self.sh("apt-get install -y --allow-downgrades libflux1=1.4.2-1", check=True)
        self.sh("echo 'tool install' | dpkg --set-selections", check=True)
        self.sh("apt-mark hold libflux1", check=True)
        r = self.sh("dpkg --get-selections", check=True)
        self.assertRegex(r.stdout, r"libflux1\s+hold\n")
        self.assertRegex(r.stdout, r"tool\s+install\n")
        r = self.sh("apt-get -s upgrade", check=True)
        self.assertIn("The following packages have been kept back:\n  libflux1\n", r.stdout)
        self.assertNotIn("Inst libflux1", r.stdout)
        r = self.sh("apt-get -s dist-upgrade", check=True)
        self.assertNotIn("Inst libflux1", r.stdout)

    def test_verify_and_search(self):
        sb, _ = self.make()
        root = sb / "rootfs"
        self.sh("apt-get install -y fluxd", check=True)
        self.assertEqual(self.sh("dpkg -V").stdout, "")
        with open(root / "usr/bin/fluxd", "a") as f:
            f.write("tampered\n")
        with open(root / "etc/fluxd/fluxd.conf", "a") as f:
            f.write("edited=1\n")
        r = self.sh("dpkg -V")
        self.assertEqual(r.stdout, "??5?????? c /etc/fluxd/fluxd.conf\n??5??????   /usr/bin/fluxd\n")
        self.assertEqual(self.sh("dpkg -S /usr/bin/fluxd").stdout, "fluxd: /usr/bin/fluxd\n")
        r = self.sh("dpkg -S /bin/fluxd")     # usrmerge: the package lists /usr/bin/fluxd
        self.assertEqual(r.returncode, 1)
        self.assertIn("no path found matching pattern /bin/fluxd", r.stderr)
        self.assertIn("/etc/fluxd/fluxd.conf\n", self.sh("dpkg -L fluxd").stdout)
        deb = next((sb / "repos/ubuntu/pool").rglob("fluxd_3.2.0-1_*.deb"))
        self.sh(f"dpkg-deb -x {deb} restore && cp restore/usr/bin/fluxd rootfs/usr/bin/fluxd", check=True)
        self.assertEqual(self.sh("dpkg -V fluxd").stdout, "??5?????? c /etc/fluxd/fluxd.conf\n")

    def test_signed_repo_and_wrong_key(self):
        sb, _ = self.make()
        r = self.sh("apt-get update", check=True)
        self.assertNotRegex(r.stdout + r.stderr, r"(?m)^(W|E|Err):")
        keyring = sb / "rootfs/etc/apt/keyrings/ubuntu.gpg"
        keyring.write_bytes(pgp.export_public(pgp.load_key("key1")))
        r = self.sh("apt-get update")
        self.assertIn(f"NO_PUBKEY {pgp.load_key('key3').keyid}", r.stdout + r.stderr)
        self.assertRegex(r.stderr, r"(?m)^W: .*signature")

    def test_prompt_is_answered_on_a_terminal(self):
        if not shutil.which("script"):
            self.skipTest("needs script(1)")
        self.make()
        self.sh("apt-get install -y fluxd", check=True)
        r = self.sh("script -qec 'apt remove fluxd' /dev/null", env={"LM_APT_ANSWER": "n"})
        out = r.stdout.replace("\r", "")
        self.assertIn("Reading package lists... Done\n", out)
        self.assertIn("Do you want to continue? [Y/n] n\nAbort.\n", out)
        self.assertNotIn("WARNING: apt does not have a stable CLI", out)
        self.assertEqual(self.status()["fluxd"][0], "ii")
        r = self.sh("script -qec 'apt-get remove fluxd' /dev/null")
        out = r.stdout.replace("\r", "")
        self.assertIn("Do you want to continue? [Y/n] Y\n", out)
        self.assertEqual(self.status()["fluxd"][0], "rc")
        self.assertIn("Commandline: apt-get remove fluxd\n", (self.sb / "rootfs/var/log/apt/history.log").read_text())
        r = self.sh("apt remove oldmon </dev/null")          # not a terminal: real apt behaviour
        self.assertIn("WARNING: apt does not have a stable CLI interface", r.stderr)

    def test_new_version_needs_update(self):
        fx = json.loads(json.dumps(FIXTURE))
        sb, _ = self.make(fx)
        fx["repos"][0]["packages"].append({"name": "tool", "version": "2.0-2"})
        fxfile = sb.parent / (sb.name + ".v2.json")
        fxfile.write_text(json.dumps(fx))
        self.addCleanup(fxfile.unlink)
        r = subprocess.run([sys.executable, str(PKG / "pkgsim.py"), "build", str(sb), str(fxfile), "--repos-only",
                            "--no-update"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("2.0-2", self.sh("apt-cache madison tool").stdout)
        self.sh("apt-get update", check=True)
        self.assertIn("2.0-2", self.sh("apt-cache madison tool").stdout)
        self.assertEqual(self.status()["tool"], ("hi", "2.0-1"))   # --repos-only left the system alone

    def test_suites_sharing_one_path(self):
        pk = lambda n, v: {"name": n, "version": v, "description": n}  # noqa: E731
        fx = {"repos": [
            {"name": "a", "suite": "noble", "path": "repos/m", "packages": [pk("x", "1.0-1")]},
            {"name": "b", "suite": "noble-updates", "codename": "noble", "path": "repos/m", "packages": [pk("x", "1.1-1")]}],
            "update": False, "base_files": False}
        sb, _ = self.make(fx)
        self.assertTrue((sb / "repos/m/dists/noble/Release").exists())
        self.assertTrue((sb / "repos/m/dists/noble-updates/Release").exists())
        self.sh("apt-get update", check=True)
        self.assertIn("1.1-1", self.sh("apt-cache policy x").stdout)

    def test_dpkg_install_local_deb(self):
        sb, _ = self.make({"repos": [{"name": "main", "packages": [{"name": "base-lib", "version": "1"}]}]})
        tree = sb / "build/DEBIAN"
        tree.mkdir(parents=True)
        (tree / "control").write_text("Package: myapp\nVersion: 1.0\nArchitecture: all\nMaintainer: Me <me@example.org>\n"
                                      "Depends: base-lib\nDescription: my app\n")
        self.sh("dpkg-deb --root-owner-group --build build myapp.deb", check=True)
        r = self.sh("dpkg -i myapp.deb")
        self.assertEqual(r.returncode, 1)
        self.assertIn("dependency problems prevent configuration of myapp", r.stderr)
        self.assertEqual(self.status()["myapp"], ("iU", "1.0"))
        r = self.sh("apt-get install -y -f")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.status()["myapp"], ("ii", "1.0"))

    def test_index_only_repo_and_maintainer_scripts(self):
        pk = [{"name": f"tool{i:02d}", "version": "1.0-1", "description": f"Helper number {i}"} for i in range(30)]
        fx = {"repos": [{"name": "big", "debs": False, "packages": pk},
                        {"name": "main", "packages": [{"name": "agentd", "version": "1",
                                                       "scripts": {"postinst": "#!/bin/sh\nset -e\n"
                                                                   "mkdir -p \"$DPKG_ROOT/var/lib/agentd\"\n"}}]}],
              "installed": ["agentd"]}
        sb, _ = self.make(fx)
        self.assertTrue((sb / "rootfs/var/lib/agentd").is_dir())
        r = self.sh("apt-cache search --names-only 'tool1[0-2]'", check=True)
        self.assertEqual(r.stdout, "tool10 - Helper number 10\ntool11 - Helper number 11\ntool12 - Helper number 12\n")
        r = self.sh("apt-get install -y tool05")
        self.assertNotEqual(r.returncode, 0)

    def test_fixture_errors(self):
        _, r = self.make({"repos": [], "installed": [{"name": "ghost", "version": "1"}]}, check=False)
        self.assertEqual(r.returncode, 1)
        self.assertIn("ghost", r.stderr)
        _, r = self.make({"repos": [{"name": "m", "packages": [{"name": "a", "version": "1"}]}],
                          "installed": [{"name": "a", "state": "zz"}]}, check=False)
        self.assertIn("bad state", r.stderr)
        _, r = self.make({"repos": [{"name": "m", "packages": [{"name": "a", "version": "1"},
                                                                {"name": "a", "version": "1"}]}]}, check=False)
        self.assertIn("listed twice", r.stderr)
        broken = {"repos": [], "files": {"/etc/apt/sources.list": "deb [trusted=yes] file:/nonexistent x main\n"}}
        _, r = self.make(broken, check=False)
        self.assertEqual(r.returncode, 1)
        self.assertIn("apt-get update failed", r.stderr)
        self.make(dict(broken, update="try"))          # a level that wants a broken setup says so
        self.make(dict(broken, update=False))
        self.make({"keyrings": {"/etc/apt/keyrings/k.gpg": {"key": "key2", "uid": "K <k@example.org>"},
                                "/etc/apt/trusted.gpg.d/both.asc": ["key1", "key4"]}})
        r = subprocess.run(["gpgv", "--keyring", str(self.sb / "rootfs/etc/apt/keyrings/k.gpg"), "/dev/null"],
                           capture_output=True, text=True)
        self.assertNotIn("keyring", r.stderr.lower().replace("--keyring", ""))
        self.assertTrue((self.sb / "rootfs/etc/apt/trusted.gpg.d/both.asc").read_text().startswith(
            "-----BEGIN PGP PUBLIC KEY BLOCK-----"))


if __name__ == "__main__":
    unittest.main()
