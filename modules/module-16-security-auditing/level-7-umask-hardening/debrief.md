# The Race Before chmod

## Why it works
`command > file` followed by `chmod 600 file` leaves a window: for a few milliseconds the
file exists with the mode the umask allows (often 644), and any process that opens it in
that window keeps a readable descriptor even after the chmod. This is a classic race
condition. The fix is to have the right mode at creation time: the kernel computes a new
file's mode as `666 & ~umask`, so `umask 077` gives 600 (and 700 for new directories).
Doing it in a subshell, `( umask 077; ... )`, keeps the change local, so the caller's
umask is not altered for the rest of the session.

The check swaps `chmod` for a no-op and runs the script under umask 000, 022 and 077. A key
that is only private because of the chmod comes out world-readable.

## Common mistakes
- Keeping `chmod 600` after the redirect and calling it fixed: the window is still there.
- `mkdir -p -m 700 a/b` only applies the mode to `b`; the parent `a` is made with the umask.
- Setting `umask 077` in the caller's shell and forgetting it: later files are all private.

## Next step
`install -m 600 /dev/null file` and `mktemp` also create files with a safe mode atomically;
`openssl` writes private keys with 600 when you use `umask 077` or `-out` on a pre-created file.
