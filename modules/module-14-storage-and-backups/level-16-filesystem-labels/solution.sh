#!/bin/bash
# Look inside each image without mounting it (debugfs), label accordingly, then
# switch the first field of the two fstab lines.
for img in data.img backup.img; do
  if debugfs -R 'ls /' "$img" 2>/dev/null | grep -qw db; then e2label "$img" DATA; else e2label "$img" BACKUP; fi
done
sed -i -E 's#^[^[:space:]]+([[:space:]]+/srv/data[[:space:]])#LABEL=DATA\1#; s#^[^[:space:]]+([[:space:]]+/srv/backup[[:space:]])#LABEL=BACKUP\1#' etc/fstab
for img in data.img backup.img; do e2label "$img"; done
cat etc/fstab
