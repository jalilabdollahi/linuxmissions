# Checksums That Won't Check

## Why it works
`sha256sum -c` reads a list of "hash, name" pairs, recomputes each hash and prints `OK` or `FAILED`.
It understands the GNU format (`hash  name`, `hash *name` for binary mode) and the BSD format
(`SHA256 (name) = hash`), but it is picky: a line with a single space is "improperly formatted" and
skipped with a warning, and a name like `dist/agent.zip` is looked up literally, so when the file is just
`agent.zip` it counts as missing. `--ignore-missing` exists for lists that cover more than you
downloaded, but it also hides exactly this kind of mismatch: the check "passes" while verifying only a
few files. That is why you count the verdicts: six downloads, six lines in `verify.log`. Windows CRLF
line endings (also present here) are tolerated by coreutils 9.x but made every check fail on older systems.

The value of a checksum depends on where the list came from: a SUMS file fetched from the same mirror only
catches accidents. For tampering you need the list (or its signature, see the previous level) from the vendor.

## Common mistakes
- Running the check from another directory: the names are relative, so every file is "missing".
- Trusting a clean-looking run without counting that every downloaded file got a verdict.
- Deleting the corrupted file instead of keeping it in quarantine for analysis.

## Next step
`sha256sum --status -c LIST` prints nothing and returns only an exit code, ideal for scripts, and
`sha256sum --strict` rejects improperly formatted lines instead of skipping them.
