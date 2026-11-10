# The Rescue Toolkit Will Not Start

## Why it works
A dynamically linked program stores the names (SONAMEs) of the libraries it needs in its
`NEEDED` entries, and the loader finds each one by that exact name in its search path. `ldd` runs
the real loader with the rescue system's paths, so it found the host's libraries and reported
nothing missing; the toolkit, which brings its own, has to be checked against its own
directory, with `readelf -d` for the names and a walk down the dependency chain (jq needs
`libjq`, which needs `libonig`). The package cache had two builds: you had to pick the one
whose file really provides the missing SONAME, unpack it with `dpkg-deb -x`, and add the link
`libX.so.N -> libX.so.N.M.P` that `ldconfig` would normally create.

## Common mistakes
- Trusting `ldd` on the toolkit's binary and concluding that nothing is missing.
- Copying the versioned file but not creating the SONAME link: the loader still cannot find the name.
- Taking the older package because its version number looked right.

## Next step
`LD_DEBUG=libs` makes the loader print where each library came from, and
`ld.so --list` or `LD_LIBRARY_PATH` give faster checks on a normal system. `patchelf --set-rpath`
and `ldconfig -n DIR` are the tools for fixing search paths and creating SONAME links in bulk.
