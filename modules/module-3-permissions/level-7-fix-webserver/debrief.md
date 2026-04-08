# Web Server 403

## Key insight
**Never use `chmod -R 644 /var/www`** — it makes directories untraversable (you need execute on dirs to enter them).

The right pattern:
```bash
find /var/www -type d -exec chmod 755 {} \;
find /var/www -type f -exec chmod 644 {} \;
```

## Why execute on directories?
`x` on a directory means "can enter/traverse this directory". Without it, even `ls` and `cd` fail.

## Commands to remember
```bash
# Fix web root permissions
find /var/www -type d -exec chmod 755 {} \;
find /var/www -type f -exec chmod 644 {} \;

# Alternative with +/- (safer for mixed states)
find /var/www -type d -exec chmod u+rwx,go+rx,go-w {} \;
find /var/www -type f -exec chmod u+rw,go+r,go-wx {} \;
```
