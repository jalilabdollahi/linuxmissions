# Bulk Renamer

## What you practiced
Loops let you apply the same operation to many files. Parameter expansion like `${file%.txt}` is a fast way to rewrite filenames.

## Commands to remember
```bash
for file in "$dir"/*.txt; do
  mv "$file" "${file%.txt}.bak"
done
basename "$file"
```
