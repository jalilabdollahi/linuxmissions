# Find and Replace

## What you practiced
- `sed 's/old/new/g'` — the g flag replaces ALL occurrences per line (without g, only the first)
- `sed -i` edits the file in-place (dangerous without a backup)
- `sed -i.bak` edits in-place and keeps a `.bak` backup

## Commands to remember
```bash
sed 's/foo/bar/g' file              # replace, print to stdout
sed 's/foo/bar/g' file > new        # save to new file
sed -i 's/foo/bar/g' file           # in-place edit
sed -i.bak 's/foo/bar/g' file       # in-place with backup
sed 's/^/PREFIX: /' file            # prepend to each line
sed 's/$/ SUFFIX/' file             # append to each line
sed '/^#/d' file                    # delete comment lines
sed -n '10,20p' file                # print lines 10-20
```
