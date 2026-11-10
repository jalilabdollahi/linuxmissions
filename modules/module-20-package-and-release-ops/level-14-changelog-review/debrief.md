# Was CVE-2026-1182 Fixed?

## Why it works
A Debian changelog lists releases newest first, and every entry starts with a header line
`package (version) suite; urgency=...`. The first version that *fixes* the CVE is the oldest entry
that really says so, which is the last one you meet when reading from the top. A revert switches the
fix off until it is applied again, so a version that is newer than the first fix can still be unpatched.
Walking the entries from oldest to newest with a single "is it fixed now" flag handles all three cases.

## Common mistakes
- Taking the first grep hit (it is the newest mention, here the re-apply or a revert).
- Matching `CVE-2026-1182` without a word boundary: `CVE-2026-11820` is another vulnerability.
- Comparing the installed version to the first fix with `dpkg --compare-versions` only: that ignores
  the revert in between.
- Counting an entry that only mentions the CVE ("investigating", "document in README") as a fix.

## Next step
`apt changelog PKG` (needs network) and `zless /usr/share/doc/PKG/changelog.Debian.gz` read the same file on a real
system; Ubuntu's security notices (USN) list the first fixed version per release.
