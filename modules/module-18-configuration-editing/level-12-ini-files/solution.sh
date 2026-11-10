#!/bin/bash
# Only the first [mysqld] block: replace the real max_connections line (anchored,
# so the comment is safe) and add the new setting after it.
awk '
  /^\[mysqld\]/ && !done { inblk = 1 }
  /^\[/ && !/^\[mysqld\]/ { inblk = 0 }
  inblk && /^max_connections[[:space:]]*=/ { print "max_connections = 500"; print "innodb_buffer_pool_size = 2G"; done = 1; inblk = 0; next }
  { print }
' my.cnf > my.cnf.new && mv my.cnf.new my.cnf
diff .lm-state/original.cnf my.cnf
