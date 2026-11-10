#!/bin/bash
# Prune for Everyone: prune.sh was written during an incident: it cds into a
# hard-coded folder, keeps 7, splits names on spaces and logs to stdout. The
# player turns it into a tool with options, a config file, environment
# overrides, clean stdout, and documented exit codes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p backups/archive

# name|mtime (oldest first); names and mtimes are not in the same order
i=0
while IFS='|' read -r name stamp; do
  echo "backup $i" > "backups/$name"
  touch -t "$stamp" "backups/$name"
  i=$((i + 1))
done <<'LIST'
db-2026-10-30.tar.gz|202610300200
db-2026-10-31.tar.gz|202610310200
db-2026-11-01.tar.gz|202611010200
manual before upgrade.tar.gz|202611011415
db-2026-11-02.tar.gz|202611020200
db-2026-11-03.tar.gz|202611030200
db-2026-11-04.tar.gz|202611040200
db-2026-11-05.tar.gz|202611050200
db-2026-11-06.tar.gz|202611060200
db-2026-11-07.tar.gz|202611070200
LIST
echo "restore with: tar xzf FILE" > backups/README.txt
echo "old" > backups/archive/db-2025-12-31.tar.gz
touch -t 202512310200 backups/archive/db-2025-12-31.tar.gz

cat > prune.sh <<'SCRIPT'
#!/bin/bash
# prune.sh - delete old backups, keep the 7 newest
# (written in a hurry during the disk-full incident)
cd backups
echo "pruning backups, keeping 7"
for f in $(ls -t *.tar.gz | tail -n +8); do
  rm -v $f
done
echo "done"
SCRIPT
chmod +x prune.sh

cat > prune.conf.example <<'CONF'
# prune.conf - read from $PRUNE_CONFIG, or else ~/.config/prune.conf
# key=value lines; # starts a comment
keep=14
dir=/srv/backups/db
CONF

cat > REQUEST.txt <<'TXT'
From: platform team
We want everyone to use prune.sh, from cron and from other scripts:

  prune.sh [OPTIONS] [DIR]
  Deletes the *.tar.gz files directly in DIR (default: backups), except the
  N most recently modified ones. Subfolders and other files are not touched.

  -k N, --keep N, --keep=N   how many to keep (default 7; must be a number)
  -n, --dry-run              print what would be deleted, delete nothing
  -h, --help                 usage text on stdout, exit 0
  --                         end of options (for a DIR starting with -)

  Settings, each overriding the one before:
    built-in defaults -> config file ($PRUNE_CONFIG, or ~/.config/prune.conf;
    keep=N and dir=PATH lines) -> environment (PRUNE_KEEP, PRUNE_DIR)
    -> command line (-k/--keep, DIR)

  stdout: only the names of the deleted (or, with -n, to-be-deleted) files,
          one per line, oldest first. Callers pipe this into their reports.
  stderr: every other message.
  exit:   0 done (also when there was nothing to delete)
          1 DIR does not exist
          2 usage error: unknown option, missing or non-numeric N, two DIRs
  Running it twice in a row must be harmless: the second run deletes nothing.
TXT
