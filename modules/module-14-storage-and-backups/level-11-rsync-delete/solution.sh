#!/bin/bash
# Dry run first (-n), itemized (-i), with the notes excluded from deletion; keep
# only the *deleting lines. Then the real run with the same options.
rsync -a -n -i --delete --exclude=/.local-notes releases/ mirror/ | grep '^\*deleting' > plan.txt
cat plan.txt
rsync -a --delete --exclude=/.local-notes releases/ mirror/
