#!/bin/bash
# Look at how the names are stored, then extract just that member.
tar -tzf etc-backup.tar.gz | grep nginx
tar -xzf etc-backup.tar.gz -C restore ./etc/nginx
