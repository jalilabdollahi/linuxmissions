# Sources Cleanup

## Why it works
apt reads `/etc/apt/sources.list` and every `*.list` and `*.sources` file in
`sources.list.d/`. Each (URI, suite, component) is an index target; defining the same
target in two places gives "Target Packages is configured multiple times". A suite that
does not exist on the mirror (`noble-update` instead of `noble-updates`) has no Release
file, which is the error. The deb822 `.sources` format (Ubuntu's default since 24.04) says
the same as a one-line entry but with named fields, `Signed-By:` included, and several suites
can share one stanza.

## Common mistakes
- Deleting the duplicate from the wrong place and losing a suite: check candidates, not
  just the absence of warnings (`apt-cache policy curl`).
- Converting the vendor entry but leaving the `.list` file behind: duplicate again.
- Writing `Signed-By` with a relative path, or leaving it out and trusting a global key.

## Next step
`apt-get indextargets` lists every target apt derived from your sources, and `apt
modernize-sources` (apt 2.9+) converts one-line files to deb822 for you.
