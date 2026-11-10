# Promotion Gate

## Why it works
A promotion gate is a chain of independent checks, each reduced to an exit status, run in a fixed order so that the first
failure gives one clear reason. Signature first (nothing else in the build can be trusted until the checksums file is
authentic), then the checksum of the artifact, then policy checks that need only metadata: the version (strictly newer
than prod, compared with a real version comparison: 1.10.0 beats 1.9.5, and an equal version is a rebuild, not a release),
a changelog heading for that exact version, and finally the layout read from `tar -tv` without extracting anything.
Printing exactly one line and using the exit status makes the script usable from a pipeline.

## Common mistakes
- String comparison (`[[ $v > $prod ]]`, `sort` without `-V`) and `>=` instead of strictly newer.
- `grep -q "$ver" CHANGELOG.md`: `1.4.4` also matches `1.4.40` and a mention in another entry; match the heading.
- Checking `sha256sum -c` before the signature: a forged SHA256SUMS then passes.
- Verifying the signature against a file you did not just check, or trusting any key in the default keyring instead of `keys/release.gpg`.
- Letting `set -e` or a missing tarball produce no output instead of a reason, or printing extra lines.

## Next step
`gpgv --status-fd 1` explains why a signature failed, `tar --numeric-owner -tvzf` is a quick audit of any release, and the same
gates make a good `pre-deploy` CI step: keep the verdict line machine-readable and the details on stderr.
