#!/bin/bash
# Storage request for a new log volume. The size (48-128 MiB), label, reserved
# percentage and the inode density change per run; REQUEST.txt states them and
# .lm-state/spec keeps them for the validator. Nothing is built: the player
# creates logs.img from scratch.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
SIZE=$(pick 48 64 96 128)
LABEL=$(pick LOGS APPLOGS WEBLOGS AUDITLOG)
RESERVED=$(pick 1 2 3)
RATIO=$(pick 1024 2048)

printf 'SIZE_MIB=%s\nLABEL=%s\nRESERVED=%s\nRATIO=%s\n' "$SIZE" "$LABEL" "$RESERVED" "$RATIO" > .lm-state/spec

cat > REQUEST.txt <<EOF
Storage request #4412  (app team -> infra)

We need a new volume for the application logs of the "ingest" service.

  - file system:   ext4
  - size:          exactly ${SIZE} MiB (use the whole image, no spare room left over)
  - volume label:  ${LABEL}
  - reserved:      ${RESERVED}% of the blocks. It is a data volume, root never
                   writes to it, so the default root reserve is a waste.
  - inodes:        the service writes millions of tiny files (about 1 KiB each),
                   so we need at least one inode for every ${RATIO} bytes of space.

Until the real disk arrives, build it as the image file logs.img in this directory.
EOF
