# Wrong Owner

## What you practiced
- `chown user file` changes owner
- `chown user:group file` changes both owner and group
- `chown -R` applies recursively to directories
- Only root can change ownership to someone else

## Commands to remember
```bash
chown alice file                 # change owner to alice
chown alice:developers file      # change owner and group
chown :developers file           # change group only (same as chgrp)
chown -R www-data /var/www       # web server fix
stat -c "%U %G" file             # show owner and group
ls -la                           # shows owner and group in columns 3 & 4
```
