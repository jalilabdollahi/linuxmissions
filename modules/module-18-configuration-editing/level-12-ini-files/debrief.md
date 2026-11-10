# Tune the Database Section

## Why it works
INI files are sections of `key = value` lines, and the same key can mean different
things in different sections. A section-aware edit (an awk flag, or a sed range from one
header to the next) changes one place and leaves `max_allowed_packet` of `[client]` and
`[mysqldump]` alone. The anchored pattern `^max_connections` skips the comment that
mentions the word. The second `[mysqld]` block is legal and MySQL merges it with the first,
but the new tuning belongs with the other server settings, not at the end of the file.

## Common mistakes
- `sed -i 's/max_connections.*/.../'` on the whole file also rewrites the comment.
- Appending the new line to the end of the file: it ends up in whichever section is last.
- Rewriting the file with a library that drops comments and reorders keys.

## Next step
`diff` against a saved copy is the review step for any config edit; for strict INI files,
python3's `configparser` can read them, but it rewrites comments away, so use it to check, not to edit.
