# Pack and Unpack

## What you practiced
- `tar -xzf` — **x**tract, g**z**ip, **f**ile
- `tar -czf` — **c**reate, g**z**ip, **f**ile
- `-C dir` changes to that directory before acting
- `-t` lists archive contents without extracting

## tar flag cheatsheet
| Flag | Meaning |
|------|---------|
| `-c` | Create archive |
| `-x` | Extract archive |
| `-t` | List contents |
| `-z` | gzip compression |
| `-j` | bzip2 compression |
| `-J` | xz compression |
| `-f` | Next arg is filename |
| `-v` | Verbose output |
| `-C` | Change to directory |

## Commands to remember
```bash
tar -czf backup.tar.gz /path/to/dir    # create
tar -xzf backup.tar.gz -C /dest        # extract to dest
tar -tzf backup.tar.gz                 # list contents
tar -xzf backup.tar.gz --strip=1       # strip top-level dir
```
