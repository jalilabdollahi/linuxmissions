# Compose After the Hotfix

## Why it works
YAML expresses structure with indentation: every key of a mapping must start in the
same column, and tab characters are not allowed for indentation at all. The hotfix had a
tab on one line and an entry three spaces too deep, which the parser reads as the
continuation of the previous value. Replacing exactly those leading characters fixes the
structure without touching the content. The version bump uses an address (`/shop\/worker:/`)
so only the line of the worker image changes, while the api line with the very same tag stays.

## Common mistakes
- `sed s/2.7.0/2.7.1/` on the whole file also moves the api service.
- Replacing the tab with the wrong number of spaces: it parses, but the key lands in the wrong mapping.
- Re-typing the file from memory and dropping a comment or a key.

## Next step
`python3 -c 'import yaml,sys; print(yaml.safe_load(open(sys.argv[1])))' file.yml` shows the tree the parser
really sees; compare it with what you meant, not with what the editor shows.
