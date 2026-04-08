# Octal Surgery

## What you practiced
Octal notation: three digits for owner / group / others.
Each digit = sum of r(4) + w(2) + x(1).

| Octal | Symbolic | Common use |
|-------|----------|------------|
| 644   | rw-r--r-- | Web content, config files |
| 755   | rwxr-xr-x | Executables, directories |
| 600   | rw------- | Private keys, secrets |
| 700   | rwx------ | Private scripts |
| 777   | rwxrwxrwx | Never use this in production |

## Commands to remember
```bash
chmod 644 file          # standard file
chmod 755 script.sh     # executable
chmod 600 ~/.ssh/id_rsa # SSH private key (required by ssh)
chmod -R 755 dir/       # recursive
stat -c "%a %n" file    # show octal permission
```
