# 20-Byte Backups

## Why it works
A pipeline reports the status of its last command, so `pg_dump | gzip`
succeeded whenever gzip did, and gzip happily compressed whatever half of
the dump arrived (an empty input gives a 20-byte .gz). `set -o pipefail`
makes the pipeline fail when any stage fails. Running the pipeline as an
`if` condition keeps set -e from exiting at once, so the script can copy
`PIPESTATUS`, delete the partial file and say which stage broke.

pipefail changes every pipeline in the script, though. `grep warning | wc -l`
used to be fine; with pipefail, grep's "nothing found" (exit 1) fails the
pipeline and set -e killed a perfect night. `grep -c ... || true` states that
no match is an acceptable answer.

## Common mistakes
- Reading `$PIPESTATUS` after another command (even `[`): it describes the
  most recent pipeline, which is then that command.
- `grep -c pattern file | ...`: grep -c prints 0 AND exits 1 with no match.
- Checking only `$?` of the pipeline: with pipefail you know that something
  failed, not what; the message on call at 3 a.m. should say which part.

## Learn next
`gzip -t backups/db.sql.gz` tests an archive without unpacking it, and a
restore test (`zcat db.sql.gz | psql scratch_db`) is the only real proof a
backup works. In SIGPIPE cases (`yes | head`) the writer gets status 141;
pipefail counts that as a failure too.
