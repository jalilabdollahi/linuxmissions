#!/bin/bash
ls -l db-backup.tar.gz
split -b 5000000 db-backup.tar.gz outgoing/db-backup.tar.gz.part-
sha256sum db-backup.tar.gz > outgoing/db-backup.sha256
ls -l outgoing
