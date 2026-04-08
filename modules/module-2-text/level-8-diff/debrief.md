# Spot the Difference

## What you practiced
- `diff file1 file2` shows what needs to change to make file1 look like file2
- `-u` gives unified format: `---` old, `+++` new, `-` removed, `+` added
- A `.diff` or `.patch` file can be applied with `patch`

## Commands to remember
```bash
diff file1 file2                     # basic diff
diff -u file1 file2                  # unified format (git-style)
diff -r dir1 dir2                    # recursive directory diff
diff --color file1 file2             # colorized output
patch file < changes.diff            # apply a patch
patch -R file < changes.diff         # reverse a patch
vimdiff file1 file2                  # side-by-side in vim
```
