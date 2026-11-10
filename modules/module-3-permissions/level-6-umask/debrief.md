# Default Lockdown

## Why it works
A program asks for mode 666 for new files (777 for directories) and the kernel
removes the umask bits: `mode = requested & ~umask`. With `umask 027`:

| | requested | minus umask 027 | result |
|---|---|---|---|
| file | rw-rw-rw- (666) | group w, others rwx | rw-r----- (640) |
| dir  | rwxrwxrwx (777) | group w, others rwx | rwxr-x--- (750) |

Setting the umask inside the start script means the policy travels with the
app, whatever the umask of the shell or service manager that starts it.

## Common mistakes
- Thinking the umask is subtracted as a number. It is a bit mask: `666 - 027`
  would give 637, but the real result is 640 (there is no x to remove from files).
- Fixing the umask and forgetting the files that already exist. umask only
  applies at creation time; existing files need `chmod` (or recreating).

## Learn next
`umask -S` shows the umask symbolically (`u=rwx,g=rx,o=`), and you can set it
that way too. For services, systemd has `UMask=0027` in the unit file.
