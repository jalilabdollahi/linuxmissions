# Shared Space

## Why it works
Removing a file means changing the directory that lists it, so normally anyone
with `w` on the directory can delete anything inside. The **sticky bit** (`t`,
octal `1000`) adds one rule: in this directory, only the file's owner, the
directory's owner or root may delete or rename a file. Everyone can still create
files, which is exactly what `/tmp` needs (`drwxrwxrwt`).

## Common mistakes
- `chmod 755 shared` to "stop the deletes": it also stops everyone else from
  uploading. The sticky bit fixes deletion without taking away writing.
- Expecting the sticky bit to protect file *contents*: someone who has `w` on a
  file can still empty it. Use `644` on the files for that.
- A capital `T` in `ls -ld` means sticky is set but `x` for others is not, so
  others can't enter the directory: usually a mistake.

## Learn next
The setgid bit on a directory (`chmod g+s dir`, `2775`) makes new files inherit
the directory's group, which is the other half of a good team folder.
