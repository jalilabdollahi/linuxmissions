# Script Won't Run

## What you practiced
- Linux has three permission types: **read (r)**, **write (w)**, **execute (x)**
- Three entities: **user/owner (u)**, **group (g)**, **others (o)**
- `chmod u+x` adds execute for owner; `chmod +x` adds for all

## Permission notation
`-rwxr-xr--` means:
- `-` = regular file (d = directory)
- `rwx` = owner: read, write, execute
- `r-x` = group: read, execute
- `r--` = others: read only

## Commands to remember
```bash
chmod +x script.sh              # add execute for everyone
chmod u+x script.sh             # add execute for owner only
chmod 755 script.sh             # rwxr-xr-x
chmod 644 file.txt              # rw-r--r--
ls -la                          # show permissions
stat file                       # detailed file metadata
```
