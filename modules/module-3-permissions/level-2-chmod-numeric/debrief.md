# Octal Surgery

## Why it works
An octal mode is three digits, owner / group / others, and each digit is the sum
of read (4), write (2) and execute (1). `chmod 644` *sets* all nine bits at once,
so it removes the dangerous `w` for group/others that `777` had added, in one step.

| Octal | Symbolic    | Typical use                    |
|-------|-------------|--------------------------------|
| 644   | rw-r--r--   | web pages, normal config files |
| 755   | rwxr-xr-x   | programs, scripts, directories |
| 600   | rw-------   | passwords, SSH private keys    |
| 777   | rwxrwxrwx   | almost never correct           |

## Common mistakes
- Mixing up the order: the first digit is the **owner**, the last is **others**.
  `chmod 006` gives strangers access and locks you out.
- Using `chmod +x` on secrets or config files "just in case". Data files never
  need execute.

## Learn next
`stat -c '%a %A %n' *` (GNU) prints both forms side by side. `ssh` refuses to use a
private key that is not `600`; try `chmod 644 ~/.ssh/id_ed25519` on a test key and
read the warning.
