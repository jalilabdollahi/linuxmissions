"""Minimal OpenPGP (RFC 4880) signing for LinuxMissions package fixtures.

The reference image has `gpgv` but no `gpg`, so repositories are signed here
with plain Python: RSA keys (v4, PKCS#1 v1.5, SHA-512) whose public halves
gpgv and apt accept. The keys in keys/*.json are TEST KEYS ONLY; their secret
parts are committed on purpose so any level can sign its own repository at
setup time. Never use them for anything real.

  python3 pgp.py list
  python3 pgp.py fingerprint KEY
  python3 pgp.py export KEY --uid "Name <mail>" [--armor] > keyring.gpg
  python3 pgp.py clearsign KEY FILE [--time EPOCH] > InRelease
  python3 pgp.py sign KEY FILE [--armor] [--time EPOCH] > FILE.sig   (detached)
  python3 pgp.py genkey NAME --created EPOCH [--bits 3072]          (maintainers)

KEY is a name from keys/ (key1 ... key4) or a path to such a JSON file.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import struct
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
KEY_DIR = os.path.join(HERE, "keys")

PUBKEY_RSA = 1
HASH_SHA512, HASH_SHA256 = 10, 8
_DIGEST_INFO = {
    HASH_SHA512: bytes.fromhex("3051300d060960864801650304020305000440"),
    HASH_SHA256: bytes.fromhex("3031300d060960864801650304020105000420"),
}
_HASH_NAME = {HASH_SHA512: "SHA512", HASH_SHA256: "SHA256"}


# ─── keys ───────────────────────────────────────────────────────────────────

class Key:
    def __init__(self, data: dict):
        self.name = data["name"]
        self.n = int(data["n"], 16)
        self.e = int(data["e"], 16)
        self.d = int(data["d"], 16)
        self.created = int(data["created"])
        self.default_uid = data.get("uid", f"LinuxMissions test key {self.name}")

    # public key packet body (v4 RSA)
    def pub_body(self) -> bytes:
        return bytes([4]) + struct.pack(">I", self.created) + bytes([PUBKEY_RSA]) + _mpi(self.n) + _mpi(self.e)

    @property
    def fingerprint(self) -> str:
        body = self.pub_body()
        return hashlib.sha1(b"\x99" + struct.pack(">H", len(body)) + body).hexdigest().upper()

    @property
    def keyid(self) -> str:
        return self.fingerprint[-16:]

    def rsa_sign(self, digest: bytes, hash_algo: int) -> bytes:
        k = (self.n.bit_length() + 7) // 8
        t = _DIGEST_INFO[hash_algo] + digest
        em = b"\x00\x01" + b"\xff" * (k - len(t) - 3) + b"\x00" + t
        return pow(int.from_bytes(em, "big"), self.d, self.n).to_bytes(k, "big")


def load_key(name_or_path: str) -> Key:
    path = name_or_path
    if not os.path.exists(path):
        path = os.path.join(KEY_DIR, f"{name_or_path}.json")
    with open(path, encoding="utf-8") as f:
        return Key(json.load(f))


def available_keys():
    return sorted(f[:-5] for f in os.listdir(KEY_DIR) if f.endswith(".json"))


# ─── packets ────────────────────────────────────────────────────────────────

def _mpi(x: int) -> bytes:
    b = x.to_bytes((x.bit_length() + 7) // 8, "big") if x else b""
    return struct.pack(">H", x.bit_length()) + b


def _packet(tag: int, body: bytes) -> bytes:
    n = len(body)
    if n < 192:
        ln = bytes([n])
    elif n < 8384:
        n2 = n - 192
        ln = bytes([(n2 >> 8) + 192, n2 & 0xFF])
    else:
        ln = b"\xff" + struct.pack(">I", n)
    return bytes([0xC0 | tag]) + ln + body


def _subpacket(typ: int, data: bytes) -> bytes:
    n = len(data) + 1
    assert n < 192
    return bytes([n, typ]) + data


def _signature(key: Key, sigtype: int, hashed_data: bytes, when: int, extra_hashed=b"",
               hash_algo=HASH_SHA512) -> bytes:
    hashed = (_subpacket(33, b"\x04" + bytes.fromhex(key.fingerprint))
              + _subpacket(2, struct.pack(">I", when)) + extra_hashed)
    head = bytes([4, sigtype, PUBKEY_RSA, hash_algo]) + struct.pack(">H", len(hashed)) + hashed
    trailer = b"\x04\xff" + struct.pack(">I", len(head))
    h = hashlib.new(_HASH_NAME[hash_algo].lower())
    h.update(hashed_data + head + trailer)
    digest = h.digest()
    unhashed = _subpacket(16, bytes.fromhex(key.keyid))
    sig = key.rsa_sign(digest, hash_algo)
    body = head + struct.pack(">H", len(unhashed)) + unhashed + digest[:2] + _mpi(int.from_bytes(sig, "big"))
    return _packet(2, body)


def export_public(key: Key, uid: str | None = None, armor: bool = False) -> bytes:
    """A transferable public key (key + user id + self-signature), as gpg --export writes it."""
    uid_b = (uid or key.default_uid).encode("utf-8")
    body = key.pub_body()
    cert_data = b"\x99" + struct.pack(">H", len(body)) + body + b"\xb4" + struct.pack(">I", len(uid_b)) + uid_b
    extra = (_subpacket(27, b"\x03")                     # key flags: certify + sign
             + _subpacket(11, bytes([9, 8, 7]))          # preferred ciphers (AES256, AES192, AES)
             + _subpacket(21, bytes([10, 9, 8]))         # preferred hashes (SHA512, SHA384, SHA256)
             + _subpacket(22, bytes([2, 3, 1]))          # preferred compression
             + _subpacket(30, b"\x01"))                  # features: MDC
    sig = _signature(key, 0x13, cert_data, key.created, extra)
    data = _packet(6, body) + _packet(13, uid_b) + sig
    return armor_block(data, "PUBLIC KEY BLOCK").encode() if armor else data


def _canonical_text(text: str) -> bytes:
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return "\r\n".join(line.rstrip(" \t\r") for line in lines).encode("utf-8")


def clearsign(key: Key, text: str, when: int | None = None) -> str:
    """An InRelease-style cleartext signed message (SHA512)."""
    when = int(time.time()) - 60 if when is None else int(when)
    sig = _signature(key, 0x01, _canonical_text(text), when)
    body = "".join(("- " + line if line.startswith("-") else line) + "\n"
                   for line in (text[:-1] if text.endswith("\n") else text).split("\n"))
    return ("-----BEGIN PGP SIGNED MESSAGE-----\nHash: SHA512\n\n" + body
            + armor_block(sig, "SIGNATURE"))


def detach_sign(key: Key, data: bytes, armor: bool = True, when: int | None = None) -> bytes:
    """A detached binary-document signature (like gpg --detach-sign [--armor])."""
    when = int(time.time()) - 60 if when is None else int(when)
    sig = _signature(key, 0x00, data, when)
    return armor_block(sig, "SIGNATURE").encode() if armor else sig


def _crc24(data: bytes) -> int:
    crc = 0xB704CE
    for byte in data:
        crc ^= byte << 16
        for _ in range(8):
            crc <<= 1
            if crc & 0x1000000:
                crc ^= 0x1864CFB
    return crc & 0xFFFFFF


def armor_block(data: bytes, kind: str) -> str:
    b64 = base64.b64encode(data).decode()
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    crc = base64.b64encode(struct.pack(">I", _crc24(data))[1:]).decode()
    return (f"-----BEGIN PGP {kind}-----\n\n" + "\n".join(lines) + f"\n={crc}\n"
            f"-----END PGP {kind}-----\n")


# ─── key generation (maintainers only; the results are committed) ──────────

def _is_probable_prime(n: int, rounds: int = 40) -> bool:
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, r = n - 1, 0
    while d % 2 == 0:
        d //= 2
        r += 1
    for _ in range(rounds):
        a = secrets.randbelow(n - 3) + 2
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(r - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def _prime(bits: int) -> int:
    while True:
        c = secrets.randbits(bits) | (1 << (bits - 1)) | (1 << (bits - 2)) | 1
        if _is_probable_prime(c):
            return c


def genkey(name: str, created: int, bits: int = 3072, uid: str | None = None) -> dict:
    e = 65537
    while True:
        p, q = _prime(bits // 2), _prime(bits // 2)
        n = p * q
        phi = (p - 1) * (q - 1)
        if p != q and n.bit_length() == bits and phi % e:
            break
    d = pow(e, -1, phi)
    return {"name": name, "comment": "LinuxMissions TEST KEY - secret part is public on purpose",
            "uid": uid or f"LinuxMissions test key {name}", "created": created,
            "n": format(n, "x"), "e": format(e, "x"), "d": format(d, "x")}


# ─── command line ───────────────────────────────────────────────────────────

def main(argv) -> int:
    def opt(name, default=None):
        if name in argv:
            i = argv.index(name)
            val = argv[i + 1]
            del argv[i:i + 2]
            return val
        return default

    def flag(name):
        if name in argv:
            argv.remove(name)
            return True
        return False

    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd = argv.pop(0)
    if cmd == "list":
        for name in available_keys():
            k = load_key(name)
            print(f"{name}\t{k.fingerprint}\t{time.strftime('%Y-%m-%d', time.gmtime(k.created))}\t{k.default_uid}")
        return 0
    if cmd == "genkey":
        created = int(opt("--created", str(int(time.time()))))
        bits = int(opt("--bits", "3072"))
        uid = opt("--uid")
        data = genkey(argv[0], created, bits, uid)
        os.makedirs(KEY_DIR, exist_ok=True)
        with open(os.path.join(KEY_DIR, f"{argv[0]}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1)
            f.write("\n")
        return 0
    when = opt("--time")
    when = int(when) if when else None
    uid = opt("--uid")
    armor = flag("--armor") or flag("-a")
    key = load_key(argv[0])
    out = sys.stdout.buffer
    if cmd == "fingerprint":
        print(key.fingerprint)
    elif cmd == "export":
        out.write(export_public(key, uid, armor))
    elif cmd == "clearsign":
        with open(argv[1], encoding="utf-8") as f:
            out.write(clearsign(key, f.read(), when).encode())
    elif cmd == "sign":
        with open(argv[1], "rb") as f:
            out.write(detach_sign(key, f.read(), armor, when))
    else:
        print(f"pgp.py: unknown command {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
