#!/bin/bash
# -k / --skip-old-files: never overwrite what exists. -p: modes as stored, regardless of umask.
# (tar already restores modification times.)
tar -tzf backups/projects-mon.tar.gz | head -5
tar -xzpf backups/projects-mon.tar.gz --skip-old-files
find projects -type f | wc -l
