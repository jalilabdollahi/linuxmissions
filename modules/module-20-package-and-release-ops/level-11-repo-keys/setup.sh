#!/bin/bash
# Key Rotation: the Acme repo is signed with test key3; the
# three keyring files hold the old vendor key, the right key and an unrelated
# one, under shuffled names. The source line has no signed-by yet, so the real
# apt update fails with NO_PUBKEY.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm" "$SANDBOX/keyrings"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim, pgp

r = random.Random()
good, other = "key3", r.choice(["key1", "key4"])   # key4 post-dates the signature time, so it can only be a decoy
names = ["acme-archive-keyring.gpg", "acme-keyring-2022.gpg", "acme-tools.gpg"]
r.shuffle(names)
rings = {names[0]: ("key2", "Acme Archive Signing Key (2022) <archive@acme.example>"),
         names[1]: (good, "Acme Archive Signing Key (2024) <archive@acme.example>"),
         names[2]: (other, "Acme Tools Release Key <tools@acme.example>")}
for fn, (k, uid) in rings.items():
    open(f"{sandbox}/keyrings/{fn}", "wb").write(pgp.export_public(pgp.load_key(k), uid))
fx = {"update": "try",
      "repos": [{"name": "acme", "suite": "noble", "origin": "Acme", "sign": good, "signed_by": None,
                 "packages": [{"name": "acme-agent", "version": "3.0-1", "description": "Acme agent"}]}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/.lm/good", "w").write(names[1] + "\n")
PY
